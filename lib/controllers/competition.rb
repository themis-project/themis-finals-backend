require 'date'

require 'ip'
require 'themis/finals/checker/result'

require './lib/controllers/competition_stage'
require './lib/controllers/round'
require './lib/controllers/team'
require './lib/controllers/service'
require './lib/controllers/remote_checker'
require './lib/controllers/team_service_state'
require './lib/controllers/score'
require './lib/controllers/scoreboard'
require './lib/controllers/scoreboard_state'
require './lib/controllers/flag'
require './lib/queue/tasks'
require './lib/constants/flag_poll_state'

module Themis
  module Finals
    module Controllers
      class Competition
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
          @stage_ctrl = ::Themis::Finals::Controllers::CompetitionStage.new
          @round_ctrl = ::Themis::Finals::Controllers::Round.new
          @team_ctrl = ::Themis::Finals::Controllers::Team.new
          @service_ctrl = ::Themis::Finals::Controllers::Service.new
          @remote_checker_ctrl = ::Themis::Finals::Controllers::RemoteChecker.new
          @team_service_state_ctrl = ::Themis::Finals::Controllers::TeamServiceState.new
          @score_ctrl = ::Themis::Finals::Controllers::Score.new

          @settings = ::Themis::Finals::Configuration.get_settings
        end

        def init
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Configuration.get_teams.each do |team_opts|
              ::Themis::Finals::Models::Team.create(
                name: team_opts.name,
                alias: team_opts.alias,
                network: team_opts.network,
                guest: team_opts.guest
              )
            end

            ::Themis::Finals::Configuration.get_services.each do |service_opts|
              ::Themis::Finals::Models::Service.create(
                name: service_opts.name,
                alias: service_opts.alias,
                hostmask: service_opts.hostmask,
                checker_endpoint: service_opts.checker_endpoint
              )
            end

            @stage_ctrl.init
            ::Themis::Finals::Controllers::ScoreboardState.enable
          end
        end

        def enqueue_start
          @stage_ctrl.enqueue_start
        end

        def enqueue_pause
          @stage_ctrl.enqueue_pause
        end

        def enqueue_finish
          @stage_ctrl.enqueue_finish
        end

        def can_trigger_round?
          stage = @stage_ctrl.current
          if stage.starting?
            return true
          end

          cutoff = ::DateTime.now
          return stage.started? && @round_ctrl.gap_filled?(cutoff)
        end

        def trigger_round
          stage = @stage_ctrl.current
          if stage.starting?
            @stage_ctrl.start
          end

          round = @round_ctrl.create_round

          @team_ctrl.all_teams(true).each do |team|
            @service_ctrl.all_services(true).each do |service|
              begin
                push_flag(team, service, round)
              rescue => e
                @logger.error(e.to_s)
              end
            end
          end
        end

        def can_poll?
          stage = @stage_ctrl.current
          return false unless stage.started? || stage.pausing? || stage.finishing?

          cutoff = ::DateTime.now
          return @round_ctrl.can_poll?(cutoff)
        end

        def trigger_poll
          flags = ::Themis::Finals::Models::Flag.all_living.all
          poll = @round_ctrl.create_poll

          @team_ctrl.all_teams(true).each do |team|
            @service_ctrl.all_services(true).each do |service|
              flag = flags.select { |f| f.team_id == team.id && f.service_id == service.id }.sample

              unless flag.nil?
                begin
                  pull_flag(flag)
                rescue => e
                  @logger.error(e.to_s)
                end
              end
            end
          end
        end

        def can_recalculate?
          stage = @stage_ctrl.current
          stage_ok = stage.started? || stage.pausing? || stage.finishing?
          stage_ok && !@round_ctrl.expired_rounds(::DateTime.now).empty?
        end

        def trigger_recalculate
          cutoff = ::DateTime.now
          positions_updated = false
          @round_ctrl.expired_rounds(cutoff).each do |round|
            updated = recalculate_round(round)
            break unless updated
            positions_updated = updated
          end

          if positions_updated
            update_total_scores

            latest_positions = \
              ::Themis::Finals::Controllers::Scoreboard.format_team_positions(
                ::Themis::Finals::Controllers::Scoreboard.get_team_positions
              )

            ::Themis::Finals::Models::DB.transaction do
              ::Themis::Finals::Models::ScoreboardPosition.create(
                created_at: ::DateTime.now,
                data: latest_positions
              )

              event_data = {
                muted: false,
                positions: latest_positions
              }

              if ::Themis::Finals::Controllers::ScoreboardState.is_enabled
                ::Themis::Finals::Utils::EventEmitter.broadcast(
                  'scoreboard',
                  event_data
                )
              else
                ::Themis::Finals::Utils::EventEmitter.emit(
                  'scoreboard',
                  event_data,
                  true,
                  false,
                  false
                )
              end
            end
          end
        end

        def can_pause?
          @stage_ctrl.current.pausing? && @round_ctrl.last_round_finished?
        end

        def pause
          @stage_ctrl.pause
        end

        def can_finish?
          @stage_ctrl.current.finishing? && @round_ctrl.last_round_finished?
        end

        def finish
          @stage_ctrl.finish
        end

        def handle_push(flag_model, status, label, message)
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            if status == ::Themis::Finals::Checker::Result::UP
              flag_model.pushed_at = ::DateTime.now
              expires = ::Time.now + @settings.flag_lifetime
              flag_model.expired_at = expires.to_datetime
              flag_model.label = label
              flag_model.save

              ::Themis::Finals::Models::DB.after_commit do
                @logger.info("Successfully pushed flag `#{flag_model.flag}`!")
                ::Themis::Finals::Queue::Tasks::PullFlag.perform_async(flag_model.flag)
              end
            else
              @logger.info("Failed to push flag `#{flag_model.flag}` (status code "\
                           "#{status})!")
            end

            @team_service_state_ctrl.update_push_state(
              flag_model.team,
              flag_model.service,
              status,
              message
            )
          end
        end

        def handle_pull(poll, status, message)
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            if status == ::Themis::Finals::Checker::Result::UP
              poll.state = ::Themis::Finals::Constants::FlagPollState::SUCCESS
            else
              poll.state = ::Themis::Finals::Constants::FlagPollState::ERROR
            end

            poll.updated_at = ::DateTime.now
            poll.save

            flag = poll.flag
            @team_service_state_ctrl.update_pull_state(
              flag.team,
              flag.service,
              status,
              message
            )

            if status == ::Themis::Finals::Checker::Result::UP
              @logger.info("Successfully pulled flag `#{flag.flag}`!")
            else
              @logger.info("Failed to pull flag `#{flag.flag}` (status code "\
                           "#{status})!")
            end
          end
        end

        def pull_flag(flag_model)
          team = flag_model.team
          service = flag_model.service
          round = flag_model.round
          poll = nil

          ::Themis::Finals::Models::DB.transaction do
            poll = ::Themis::Finals::Models::FlagPoll.create(
              state: ::Themis::Finals::Constants::FlagPollState::NOT_AVAILABLE,
              created_at: ::DateTime.now,
              updated_at: nil,
              flag_id: flag_model.id
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info("Pulling flag `#{flag_model.flag}` from service "\
                           "`#{service.name}` of `#{team.name}` ...")
              endpoint_addr = ::IP.new(team.network).to_range.first | ::IP.new(service.hostmask)
              job_data = {
                params: {
                  request_id: poll.id,
                  endpoint: endpoint_addr.to_s,
                  capsule: flag_model.capsule,
                  label: flag_model.label
                },
                metadata: {
                  timestamp: ::DateTime.now.to_s,
                  round: round.id,
                  team_name: team.name,
                  service_name: service.name
                },
                report_url: "http://#{ENV['THEMIS_FINALS_MASTER_FQDN']}/api/checker/v2/report_pull"
              }.to_json

              call_res = @remote_checker_ctrl.pull(service.checker_endpoint, job_data)
              @logger.info("REST API PULL call to #{service.checker_endpoint} returned HTTP #{call_res}")
            end
          end
        end

        private
        def push_flag(team, service, round)
          flag_model = nil
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            flag_model = ::Themis::Finals::Controllers::Flag.issue(
              team,
              service,
              round
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info("Pushing flag `#{flag_model.flag}` to service "\
                           "`#{service.name}` of `#{team.name}` ...")
              endpoint_addr = ::IP.new(team.network).to_range.first | ::IP.new(service.hostmask)
              job_data = {
                params: {
                  endpoint: endpoint_addr.to_s,
                  capsule: flag_model.capsule,
                  label: flag_model.label
                },
                metadata: {
                  timestamp: ::DateTime.now.to_s,
                  round: round.id,
                  team_name: team.name,
                  service_name: service.name
                },
                report_url: "http://#{ENV['THEMIS_FINALS_MASTER_FQDN']}/api/checker/v2/report_push"
              }.to_json

              call_res = @remote_checker_ctrl.push(service.checker_endpoint, job_data)
              @logger.info("REST API PUSH call to #{service.checker_endpoint} returned HTTP #{call_res}")
            end
          end
        end

        def recalculate_round(round)
          rel_flags = ::Themis::Finals::Models::Flag.relevant(round)

          ::Themis::Finals::Models::DB.transaction do
            init_round_scores(round)

            err_update = false
            rel_flags.each do |flag|
              begin
                update_score(flag)
              rescue => e
                @logger.error(e.to_s)
                err_update = true
              end

              break if err_update
            end

            return false if err_update

            round.finished_at = ::DateTime.now
            round.save
            round_num = round.id

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info("Round #{round_num} finished!")
            end
          end

          true
        end

        def init_round_scores(round)
          ::Themis::Finals::Models::Team.all.each do |team|
            ::Themis::Finals::Models::Score.create(
              attack_points: 0.0,
              availability_points: 0.0,
              defence_points: 0.0,
              team_id: team.id,
              round_id: round.id
            )
          end
        end

        def update_score(flag)
          ::Themis::Finals::Models::DB.transaction(
          ) do
            polls = ::Themis::Finals::Models::FlagPoll
            .where(flag_id: flag.id)
            .exclude(state: ::Themis::Finals::Constants::FlagPollState::NOT_AVAILABLE)
            .all

            @score_ctrl.charge_availability(flag, polls)

            attacks = flag.attacks
            if attacks.count == 0
              error_count = polls.count do |poll|
                poll.state == ::Themis::Finals::Constants::FlagPollState::ERROR
              end
              success_count = polls.count do |poll|
                poll.state == ::Themis::Finals::Constants::FlagPollState::SUCCESS
              end
              if error_count == 0 && success_count > 0
                @score_ctrl.charge_defence(flag)
              end
            else
              attacks.each do |attack|
                begin
                  @score_ctrl.charge_attack(flag, attack)
                  ::Themis::Finals::Controllers::Attack.consider_attack(
                    attack
                  )
                rescue => e
                  @logger.error(e.to_s)
                end
              end
            end
          end
        end

        def update_total_scores
          ::Themis::Finals::Models::Team.all.each do |team|
            begin
              update_total_score(team)
            rescue => e
              @logger.error(e.to_s)
            end
          end
        end

        def update_total_score(team)
          ::Themis::Finals::Models::DB.transaction do
            total_score = ::Themis::Finals::Models::TotalScore.first(
              team_id: team.id
            )
            if total_score.nil?
              total_score = ::Themis::Finals::Models::TotalScore.create(
                attack_points: 0.0,
                availability_points: 0.0,
                defence_points: 0.0,
                team_id: team.id
              )
            end

            attack_points = 0.0
            availability_points = 0.0
            defence_points = 0.0

            ::Themis::Finals::Models::Score.where(
              team_id: team.id
            ).each do |score|
              attack_points += score.attack_points
              availability_points += score.availability_points
              defence_points += score.defence_points
            end

            total_score.attack_points = attack_points
            total_score.availability_points = availability_points
            total_score.defence_points = defence_points
            total_score.save

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info(
                "Total score of team `#{team.name}` has been recalculated: "\
                "attack - #{total_score.attack_points} pts, "\
                "availability - #{total_score.availability_points}, "\
                "defence - #{total_score.defence_points} pts"\
              )
            end
          end
        end
      end
    end
  end
end
