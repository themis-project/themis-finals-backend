require 'json'
require './lib/utils/flag_generator'
require './lib/controllers/round'
require './lib/controllers/flag'
require './lib/controllers/score'
require './lib/utils/queue'
require 'themis/checker/result'


module Themis
    module Controllers
        module Contest
            @logger = Themis::Utils::Logger::get

            def self.push_flag(team, service, round)
                seed, flag_str = Themis::Utils::FlagGenerator::get_flag
                flag = Themis::Models::Flag.create(
                    flag: flag_str,
                    created_at: DateTime.now,
                    pushed_at: nil,
                    expired_at: nil,
                    considered_at: nil,
                    seed: seed,
                    service: service,
                    team: team,
                    round: round)
                flag.save

                @logger.info "Pushing flag '#{flag_str}' to service #{service.name} of '#{team.name}' ..."
                job_data = {
                    operation: 'push',
                    endpoint: team.host,
                    flag_id: seed,
                    flag: flag_str
                }.to_json
                Themis::Utils::Queue::enqueue "themis.service.#{service.alias}.listen", job_data
            end

            def self.push_flags
                round = Themis::Controllers::Round::start_new
                round_num = Themis::Models::Round.all.count
                @logger.info "Round #{round_num} started!"

                all_services = Themis::Models::Service.all

                Themis::Models::Team.all.each do |team|
                    all_services.each do |service|
                        begin
                            push_flag team, service, round
                        rescue => e
                            @logger.error "#{e}"
                        end
                    end
                end
            end

            def self.handle_push(flag, status, seed)
                if status == Themis::Checker::Result::UP
                    flag.pushed_at = DateTime.now
                    expires = Time.now + Themis::Configuration.get_contest_flow.flag_lifetime
                    flag.expired_at = expires.to_datetime
                    flag.seed = seed
                    flag.save
                    @logger.info "Successfully pushed flag #{flag.flag}!"

                    poll_flag flag
                else
                    @logger.info "Failed to push flag #{flag.flag} (status code #{status})!"
                end
            end

            def self.poll_flag(flag)
                team = flag.team
                service = flag.service

                poll = Themis::Models::FlagPoll.create(
                    state: :unknown,
                    created_at: DateTime.now,
                    updated_at: nil,
                    flag: flag)
                poll.save

                @logger.info "Polling flag '#{flag.flag}' from service #{service.name} of '#{team.name}' ..."
                job_data = {
                    operation: 'pull',
                    request_id: poll.id,
                    endpoint: team.host,
                    flag: flag.flag,
                    flag_id: flag.seed
                }.to_json
                Themis::Utils::Queue::enqueue "themis.service.#{service.alias}.listen", job_data
            end

            def self.poll_flags
                living_flags = Themis::Controllers::Flag::get_living

                all_services = Themis::Models::Service.all

                Themis::Models::Team.all.each do |team|
                    all_services.each do |service|
                        service_flags = living_flags.select do |flag|
                            flag.team == team and flag.service == service
                        end

                        flags = service_flags.sample Themis::Configuration::get_contest_flow.poll_count

                        flags.each do |flag|
                            begin
                                poll_flag flag
                            rescue => e
                                @logger.error "#{e}"
                            end
                        end
                    end
                end
            end

            def self.prolong_flag_lifetimes
                prolong = Themis::Configuration::get_contest_flow.poll_period

                Themis::Controllers::Flag::get_living.each do |flag|
                    flag.expired_at = flag.expired_at.to_time + prolong
                    flag.save
                end
            end

            def self.handle_poll(poll, status)
                if status == Themis::Checker::Result::UP
                    poll.state = :success
                else
                    poll.state = :error
                end

                poll.updated_at = DateTime.now
                poll.save

                flag = poll.flag
                unless flag.nil?
                    update_team_service_state(flag.team, flag.service, status)
                end

                if status == Themis::Checker::Result::UP
                    @logger.info "Successfully pulled flag #{flag.flag}!"
                else
                    @logger.info "Failed to pull flag #{flag.flag} (status code #{status})!"
                end
            end

            def self.control_complete
                living_flags = Themis::Controllers::Flag::get_living
                expired_flags = Themis::Controllers::Flag::get_expired

                if living_flags.count == 0 and expired_flags.count == 0
                    contest_state = Themis::Models::ContestState.create(
                        state: :completed,
                        created_at: DateTime.now)
                    contest_state.save

                    Themis::Controllers::Round::end_last
                end
            end

            def self.update_scores
                Themis::Controllers::Flag::get_expired.each do |flag|
                    polls = Themis::Models::FlagPoll.all(flag: flag)

                    Themis::Controllers::Score::charge_availability flag, polls

                    attacks = flag.attacks
                    if attacks.count == 0
                        if polls.count(state: :error) == 0
                            Themis::Controllers::Score::charge_defence flag
                        end
                    else
                        attacks.each do |attack|
                            Themis::Controllers::Score::charge_attack flag, attack
                        end
                    end

                    flag.considered_at = DateTime.now
                    flag.save
                end
            end

            def self.update_team_service_state(team, service, status)
                case status
                when Themis::Checker::Result::UP
                    service_state = :up
                when Themis::Checker::Result::CORRUPT
                    service_state = :corrupt
                when Themis::Checker::Result::MUMBLE
                    service_state = :mumble
                when Themis::Checker::Result::DOWN
                    service_state = :down
                when Themis::Checker::Result::INTERNAL_ERROR
                    service_state = :internal_error
                else
                    service_state = :unknown
                end

                team_service_history_state = Themis::Models::TeamServiceHistoryState.create(
                    state: service_state,
                    created_at: DateTime.now,
                    team: team,
                    service: service)
                team_service_history_state.save

                team_service_state = Themis::Models::TeamServiceState.first(
                    service: service,
                    team: team)
                if team_service_state.nil?
                    team_service_state = Themis::Models::TeamServiceState.create(
                        state: service_state,
                        created_at: DateTime.now,
                        updated_at: DateTime.now,
                        team: team,
                        service: service)
                else
                    team_service_state.state = service_state
                    team_service_state.updated_at = DateTime.now
                end

                team_service_state.save
            end
        end
    end
end
