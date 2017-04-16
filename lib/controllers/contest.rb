require 'json'
require './lib/controllers/round'
require './lib/controllers/flag'
require './lib/controllers/score'
require 'themis/finals/checker/result'
require './lib/controllers/contest_state'
require './lib/utils/event_emitter'
require './lib/controllers/attack'
require './lib/controllers/scoreboard_state'
require './lib/constants/flag_poll_state'
require './lib/constants/team_service_state'
require './lib/constants/protocol'
require './lib/controllers/token'
require './lib/controllers/scoreboard'
require 'base64'
require 'net/http'
require './lib/queue/tasks'

module Themis
  module Finals
    module Controllers
      module Contest
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.start
          ::Themis::Finals::Controllers::ContestState.start
        end

        def self.push_flag(team, service, round)
          flag = nil
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            flag = ::Themis::Finals::Controllers::Flag.issue(team, service,
                                                             round)
            round_number = ::Themis::Finals::Models::Round.where(
              'id <= ?',
              round.id
            ).count

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info "Pushing flag `#{flag.flag}` to service "\
                           "`#{service.name}` of `#{team.name}` ..."
              case service.protocol
              when ::Themis::Finals::Constants::Protocol::REST_BASIC
                job_data = {
                  params: {
                    endpoint: team.host,
                    flag: flag.flag,
                    adjunct: ::Base64.urlsafe_encode64(flag.adjunct)
                  },
                  metadata: {
                    timestamp: ::DateTime.now.to_s,
                    round: round_number,
                    team_name: team.name,
                    service_name: service.name
                  },
                  report_url: "http://#{ENV['THEMIS_FINALS_MASTER_FQDN']}/api/checker/v1/report_push"
                }.to_json

                uri = URI(service.metadata['push_url'])

                req = ::Net::HTTP::Post.new(uri)
                req.body = job_data
                req.content_type = 'application/json'
                req[ENV['THEMIS_FINALS_AUTH_TOKEN_HEADER']] = \
                  ::Themis::Finals::Controllers::Token.issue_master_token

                res = ::Net::HTTP.start(uri.hostname, uri.port) do |http|
                  http.request(req)
                end

                @logger.info res.value
              else
                @logger.error 'Not implemented'
              end
            end
          end
        end

        def self.push_flags
          round = ::Themis::Finals::Controllers::Round.start_new

          all_services = ::Themis::Finals::Models::Service.all

          ::Themis::Finals::Models::Team.all.each do |team|
            all_services.each do |service|
              begin
                push_flag team, service, round
              rescue => e
                @logger.error e.to_s
              end
            end
          end
        end

        def self.handle_push(flag, status, adjunct)
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            if status == ::Themis::Finals::Checker::Result::UP
              flag.pushed_at = ::DateTime.now
              expires = \
                ::Time.now +
                ::Themis::Finals::Configuration.get_contest_flow.flag_lifetime
              flag.expired_at = expires.to_datetime
              flag.adjunct = adjunct
              flag.save

              ::Themis::Finals::Models::DB.after_commit do
                @logger.info "Successfully pushed flag `#{flag.flag}`!"
                ::Themis::Finals::Queue::Tasks::PullFlag.perform_async flag.flag
              end
            else
              @logger.info "Failed to push flag `#{flag.flag}` (status code "\
                           "#{status})!"
            end

            update_team_service_push_state(flag.team, flag.service, status)
          end
        end

        def self.poll_flag(flag)
          team = flag.team
          service = flag.service
          round = flag.round
          poll = nil

          ::Themis::Finals::Models::DB.transaction do
            poll = ::Themis::Finals::Models::FlagPoll.create(
              state: ::Themis::Finals::Constants::FlagPollState::NOT_AVAILABLE,
              created_at: ::DateTime.now,
              updated_at: nil,
              flag_id: flag.id
            )

            round_number = ::Themis::Finals::Models::Round.where(
              'id <= ?',
              round.id
            ).count

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info "Polling flag `#{flag.flag}` from service "\
                           "`#{service.name}` of `#{team.name}` ..."
              case service.protocol
              when ::Themis::Finals::Constants::Protocol::REST_BASIC
                job_data = {
                  params: {
                    request_id: poll.id,
                    endpoint: team.host,
                    flag: flag.flag,
                    adjunct: ::Base64.urlsafe_encode64(flag.adjunct)
                  },
                  metadata: {
                    timestamp: ::DateTime.now.to_s,
                    round: round_number,
                    team_name: team.name,
                    service_name: service.name
                  },
                  report_url: "http://#{ENV['THEMIS_FINALS_MASTER_FQDN']}/api/checker/v1/report_pull"
                }.to_json

                uri = URI(service.metadata['pull_url'])

                req = ::Net::HTTP::Post.new(uri)
                req.body = job_data
                req.content_type = 'application/json'
                req[ENV['THEMIS_FINALS_AUTH_TOKEN_HEADER']] = \
                  ::Themis::Finals::Controllers::Token.issue_master_token

                res = ::Net::HTTP.start(uri.hostname, uri.port) do |http|
                  http.request(req)
                end

                @logger.info res.value
              else
                @logger.error 'Not implemented'
              end
            end
          end
        end

        def self.poll_flags
          living_flags = ::Themis::Finals::Models::Flag.all_living.all

          all_services = ::Themis::Finals::Models::Service.all

          ::Themis::Finals::Models::Team.all.each do |team|
            all_services.each do |service|
              service_flags = living_flags.select do |flag|
                flag.team_id == team.id && flag.service_id == service.id
              end

              flags = service_flags.sample(
                ::Themis::Finals::Configuration.get_contest_flow.poll_count
              )

              flags.each do |flag|
                begin
                  poll_flag flag
                rescue => e
                  @logger.error e.to_s
                end
              end
            end
          end
        end

        def self.prolong_flag_lifetime(flag, prolong_period)
          ::Themis::Finals::Models::DB.transaction do
            flag.expired_at = flag.expired_at.to_time + prolong_period
            flag.save

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info "Prolonged flag `#{flag.flag}` lifetime!"
            end
          end
        end

        def self.prolong_flag_lifetimes
          prolong_period = \
            ::Themis::Finals::Configuration.get_contest_flow.poll_period

          ::Themis::Finals::Models::Flag.all_living.each do |flag|
            begin
              prolong_flag_lifetime flag, prolong_period
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        def self.handle_poll(poll, status)
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
            update_team_service_pull_state(flag.team, flag.service, status)

            if status == ::Themis::Finals::Checker::Result::UP
              @logger.info "Successfully pulled flag `#{flag.flag}`!"
            else
              @logger.info "Failed to pull flag `#{flag.flag}` (status code "\
                           "#{status})!"
            end
          end
        end

        def self.control_complete
          contest_state = ::Themis::Finals::Models::ContestState.last
          return unless contest_state.is_await_complete

          living_flags_count = ::Themis::Finals::Models::Flag.count_living
          expired_flags_count = ::Themis::Finals::Models::Flag.count_expired

          if living_flags_count == 0 && expired_flags_count == 0
            ::Themis::Finals::Models::DB.transaction do
              ::Themis::Finals::Controllers::ContestState.complete
              ::Themis::Finals::Controllers::Round.end_last
            end
          end
        end

        def self.update_total_score(team)
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

        def self.update_total_scores
          ::Themis::Finals::Models::Team.all.each do |team|
            begin
              update_total_score team
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        def self.update_score(flag)
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            polls = ::Themis::Finals::Models::FlagPoll.where(
              flag_id: flag.id
            ).all

            ::Themis::Finals::Controllers::Score.charge_availability(
              flag,
              polls
            )

            attacks = flag.attacks
            if attacks.count == 0
              error_count = polls.count do |poll|
                poll.state == ::Themis::Finals::Constants::FlagPollState::ERROR
              end
              if error_count == 0
                ::Themis::Finals::Controllers::Score.charge_defence(flag)
              end
            else
              attacks.each do |attack|
                begin
                  ::Themis::Finals::Controllers::Score.charge_attack(
                    flag,
                    attack
                  )
                  ::Themis::Finals::Controllers::Attack.consider_attack(
                    attack
                  )
                rescue => e
                  @logger.error e.to_s
                end
              end
            end

            flag.considered_at = ::DateTime.now
            flag.save
          end
        end

        def self.update_scores
          ::Themis::Finals::Models::Flag.all_expired.each do |flag|
            begin
              update_score flag
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        def self.update_all_scores
          update_scores
          update_total_scores
          control_complete

          formatted_positions = \
            ::Themis::Finals::Controllers::Scoreboard.format_team_positions(
              ::Themis::Finals::Controllers::Scoreboard.get_team_positions
            )

          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: ::DateTime.now,
              data: formatted_positions
            )

            data = {
              muted: false,
              positions: formatted_positions
            }

            if ::Themis::Finals::Controllers::ScoreboardState.is_enabled
              ::Themis::Finals::Utils::EventEmitter.emit_all(
                'scoreboard',
                data
              )
            else
              ::Themis::Finals::Utils::EventEmitter.emit(
                'scoreboard',
                data,
                true,
                false,
                false
              )
            end
          end
        end

        def self.get_service_state(status)
          case status
          when ::Themis::Finals::Checker::Result::UP
            ::Themis::Finals::Constants::TeamServiceState::UP
          when ::Themis::Finals::Checker::Result::CORRUPT
            ::Themis::Finals::Constants::TeamServiceState::CORRUPT
          when ::Themis::Finals::Checker::Result::MUMBLE
            ::Themis::Finals::Constants::TeamServiceState::MUMBLE
          when ::Themis::Finals::Checker::Result::DOWN
            ::Themis::Finals::Constants::TeamServiceState::DOWN
          when ::Themis::Finals::Checker::Result::INTERNAL_ERROR
            ::Themis::Finals::Constants::TeamServiceState::INTERNAL_ERROR
          else
            ::Themis::Finals::Constants::TeamServiceState::NOT_AVAILABLE
          end
        end

        def self.update_team_service_push_state(team, service, status)
          ::Themis::Finals::Models::DB.transaction do
            service_state = get_service_state(status)

            ::Themis::Finals::Models::TeamServicePushHistoryState.create(
              state: service_state,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::Themis::Finals::Models::TeamServicePushState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::Themis::Finals::Models::TeamServicePushState.create(
                  state: service_state,
                  created_at: ::DateTime.now,
                  updated_at: ::DateTime.now,
                  team_id: team.id,
                  service_id: service.id
                )
            else
              team_service_state.state = service_state
              team_service_state.updated_at = ::DateTime.now
              team_service_state.save
            end

            ::Themis::Finals::Utils::EventEmitter.emit_all(
              'team/service/push-state',
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              updated_at: team_service_state.updated_at.iso8601
            )

            ::Themis::Finals::Utils::EventEmitter.emit_log(
              31,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state
            )
          end
        end

        def self.update_team_service_pull_state(team, service, status)
          ::Themis::Finals::Models::DB.transaction do
            service_state = get_service_state(status)

            ::Themis::Finals::Models::TeamServicePullHistoryState.create(
              state: service_state,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::Themis::Finals::Models::TeamServicePullState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::Themis::Finals::Models::TeamServicePullState.create(
                  state: service_state,
                  created_at: ::DateTime.now,
                  updated_at: ::DateTime.now,
                  team_id: team.id,
                  service_id: service.id
                )
            else
              team_service_state.state = service_state
              team_service_state.updated_at = ::DateTime.now
              team_service_state.save
            end

            ::Themis::Finals::Utils::EventEmitter.emit_all(
              'team/service/pull-state',
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              updated_at: team_service_state.updated_at.iso8601
            )

            ::Themis::Finals::Utils::EventEmitter.emit_log(
              32,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state
            )
          end
        end
      end
    end
  end
end
