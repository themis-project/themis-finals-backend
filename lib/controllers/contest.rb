require 'json'
require './lib/controllers/round'
require './lib/controllers/flag'
require './lib/controllers/score'
require './lib/utils/queue'
require 'themis/finals/checker/result'
require './lib/controllers/contest_state'
require './lib/utils/event_emitter'
require './lib/controllers/attack'
require './lib/controllers/scoreboard_state'
require './lib/constants/flag_poll_state'
require './lib/constants/team_service_state'
require './lib/controllers/ctftime'
require './lib/constants/protocol'
require 'base64'
require 'net/http'

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
              when ::Themis::Finals::Constants::Protocol::BEANSTALK
                job_data = {
                  operation: 'push',
                  endpoint: team.host,
                  flag: flag.flag,
                  adjunct: ::Base64.encode64(flag.adjunct),
                  metadata: {
                    timestamp: ::DateTime.now.to_s,
                    round: round_number,
                    team_name: team.name,
                    service_name: service.name
                  }
                }.to_json
                # TODO: deal with TTR later
                # opts = {
                #   delay: 0,
                #   ttr: ::Themis::Finals::Configuration.get_beanstalk_ttr
                # }
                ::Themis::Finals::Utils::Queue.enqueue(
                  "#{ENV['BEANSTALKD_TUBE_NAMESPACE']}.service."\
                  "#{service.alias}.listen",
                  job_data
                )
              when ::Themis::Finals::Constants::Protocol::REST_BASIC
                job_data = {
                  params: {
                    endpoint: team.host,
                    flag: flag.flag,
                    adjunct: ::Base64.encode64(flag.adjunct),
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
              flag.adjunct = ::Base64.decode64 adjunct
              flag.save
              @logger.info "Successfully pushed flag `#{flag.flag}`!"

              poll_flag flag
            else
              @logger.info "Failed to push flag `#{flag.flag}` (status code "\
                           "#{status})!"
            end

            update_team_service_state flag.team, flag.service, status
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
              when ::Themis::Finals::Constants::Protocol::BEANSTALK
                job_data = {
                  operation: 'pull',
                  request_id: poll.id,
                  endpoint: team.host,
                  flag: flag.flag,
                  adjunct: ::Base64.encode64(flag.adjunct),
                  metadata: {
                    timestamp: ::DateTime.now.to_s,
                    round: round_number,
                    team_name: team.name,
                    service_name: service.name
                  }
                }.to_json
                # opts = {
                #   delay: 0,
                #   ttr: ::Themis::Finals::Configuration.get_beanstalk_ttr
                # }
                ::Themis::Finals::Utils::Queue.enqueue(
                  "#{ENV['BEANSTALKD_TUBE_NAMESPACE']}.service.#{service.alias}"\
                  '.listen',
                  job_data
                )
              when ::Themis::Finals::Constants::Protocol::REST_BASIC
                job_data = {
                  params: {
                    request_id: poll.id,
                    endpoint: team.host,
                    flag: flag.flag,
                    adjunct: ::Base64.encode64(flag.adjunct),
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
            update_team_service_state flag.team, flag.service, status

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

        def self.update_total_score(team, scoreboard_enabled)
          ::Themis::Finals::Models::DB.transaction do
            total_score = ::Themis::Finals::Models::TotalScore.first(
              team_id: team.id
            )
            if total_score.nil?
              total_score = ::Themis::Finals::Models::TotalScore.create(
                defence_points: 0,
                attack_points: 0,
                team_id: team.id
              )
            end

            defence_points = 0.0
            attack_points = 0.0

            ::Themis::Finals::Models::Score.where(
              team_id: team.id
            ).each do |score|
              defence_points += score.defence_points
              attack_points += score.attack_points
            end

            total_score.defence_points = defence_points
            total_score.attack_points = attack_points
            total_score.save

            data = {
              id: total_score.id,
              team_id: total_score.team_id,
              defence_points: total_score.defence_points.to_f.round(4),
              attack_points: total_score.attack_points.to_f.round(4)
            }

            ::Themis::Finals::Utils::EventEmitter.emit(
              'team/score',
              data,
              true,
              scoreboard_enabled,
              scoreboard_enabled
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info(
                "Total score of team `#{team.name}` has been recalculated: "\
                "defence - #{defence_points.to_f.round(4)} pts, "\
                "attack - #{attack_points.to_f.round(4)} pts!"
              )
            end
          end
        end

        def self.update_total_scores(scoreboard_enabled)
          ::Themis::Finals::Models::Team.all.each do |team|
            begin
              update_total_score team, scoreboard_enabled
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        def self.update_score(flag, scoreboard_enabled)
          ::Themis::Finals::Models::DB.transaction(
            retry_on: [::Sequel::UniqueConstraintViolation],
            num_retries: nil
          ) do
            polls = ::Themis::Finals::Models::FlagPoll.where(
              flag_id: flag.id
            ).all

            ::Themis::Finals::Controllers::Score.charge_availability(
              flag,
              polls,
              scoreboard_enabled
            )

            attacks = flag.attacks
            if attacks.count == 0
              error_count = polls.count do |poll|
                poll.state == ::Themis::Finals::Constants::FlagPollState::ERROR
              end
              if error_count == 0
                ::Themis::Finals::Controllers::Score.charge_defence(
                  flag,
                  scoreboard_enabled
                )
              end
            else
              attacks.each do |attack|
                begin
                  ::Themis::Finals::Controllers::Score.charge_attack(
                    flag,
                    attack,
                    scoreboard_enabled
                  )
                  ::Themis::Finals::Controllers::Attack.consider_attack(
                    attack,
                    scoreboard_enabled
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

        def self.update_scores(scoreboard_enabled)
          ::Themis::Finals::Models::Flag.all_expired.each do |flag|
            begin
              update_score flag, scoreboard_enabled
            rescue => e
              @logger.error e.to_s
            end
          end
        end

        def self.update_all_scores
          scoreboard_enabled = \
            ::Themis::Finals::Controllers::ScoreboardState.is_enabled

          update_scores scoreboard_enabled
          update_total_scores scoreboard_enabled

          if scoreboard_enabled && ENV['CTFTIME_SCOREBOARD'] == 'true'
            ::Themis::Finals::Controllers::CTFTime.post_scoreboard
          end

          control_complete
        end

        def self.update_team_service_state(team, service, status)
          ::Themis::Finals::Models::DB.transaction do
            case status
            when ::Themis::Finals::Checker::Result::UP
              service_state = ::Themis::Finals::Constants::TeamServiceState::UP
            when ::Themis::Finals::Checker::Result::CORRUPT
              service_state = \
                ::Themis::Finals::Constants::TeamServiceState::CORRUPT
            when ::Themis::Finals::Checker::Result::MUMBLE
              service_state = \
                ::Themis::Finals::Constants::TeamServiceState::MUMBLE
            when ::Themis::Finals::Checker::Result::DOWN
              service_state = \
                ::Themis::Finals::Constants::TeamServiceState::DOWN
            when ::Themis::Finals::Checker::Result::INTERNAL_ERROR
              service_state = \
                ::Themis::Finals::Constants::TeamServiceState::INTERNAL_ERROR
            else
              service_state = \
                ::Themis::Finals::Constants::TeamServiceState::NOT_AVAILABLE
            end

            ::Themis::Finals::Models::TeamServiceHistoryState.create(
              state: service_state,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::Themis::Finals::Models::TeamServiceState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::Themis::Finals::Models::TeamServiceState.create(
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

            ::Themis::Finals::Utils::EventEmitter.emit_all 'team/service', {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              updated_at: team_service_state.updated_at.iso8601
            }

            ::Themis::Finals::Utils::EventEmitter.emit_log 3, {
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state
            }
          end
        end
      end
    end
  end
end
