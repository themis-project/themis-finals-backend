require 'themis/finals/attack/result'
require './lib/utils/event_emitter'
require './lib/constants/submit_result'

module Themis
  module Finals
    module Controllers
      module Attack
        def self.get_recent
          attacks = []
          ::Themis::Finals::Models::Team.all.each do |team|
            attack = ::Themis::Finals::Models::Attack.last(
              team_id: team.id,
              considered: true
            )

            unless attack.nil?
              attacks << attack
            end
          end

          attacks
        end

        def self.consider_attack(attack)
          attack.considered = true
          attack.save
        end

        def self.internal_process(attempt, team, data)
          old_code = attempt.deprecated_api

          unless data.respond_to?('match')
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID
            end
            attempt.response = r
            attempt.save
            return r
          end

          match_ = data.match(/^[\da-f]{32}=$/)
          if match_.nil?
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID
            end
            attempt.response = r
            attempt.save
            return r
          end

          flag = ::Themis::Finals::Models::Flag.exclude(
            pushed_at: nil
          ).where(
            flag: match_[0]
          ).first

          if flag.nil?
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_FLAG_NOT_FOUND
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_NOT_FOUND
            end
            attempt.response = r
            attempt.save
            return r
          end

          if flag.team_id == team.id
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_FLAG_YOURS
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_YOUR_OWN
            end
            attempt.response = r
            attempt.save
            return r
          end

          team_service_push_state = ::Themis::Finals::Models::TeamServicePushState.first(
            team_id: team.id,
            service_id: flag.service_id
          )
          team_service_push_ok = \
            !team_service_push_state.nil? && team_service_push_state.state == ::Themis::Finals::Constants::TeamServiceState::UP

          team_service_pull_state = ::Themis::Finals::Models::TeamServicePullState.first(
            team_id: team.id,
            service_id: flag.service_id
          )
          team_service_pull_ok = \
            !team_service_pull_state.nil? && team_service_pull_state.state == ::Themis::Finals::Constants::TeamServiceState::UP

          unless team_service_push_ok && team_service_pull_ok
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_SERVICE_NOT_UP
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_SERVICE_STATE_INVALID
            end
            attempt.response = r
            attempt.save
            return r
          end

          if flag.expired_at.to_datetime < ::DateTime.now
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_FLAG_EXPIRED
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_EXPIRED
            end
            attempt.response = r
            attempt.save
            return r
          end

          r = nil
          begin
            ::Themis::Finals::Models::DB.transaction do
              ::Themis::Finals::Models::Attack.create(
                occured_at: ::DateTime.now,
                considered: false,
                team_id: team.id,
                flag_id: flag.id
              )
              r = if old_code
                ::Themis::Finals::Attack::Result::SUCCESS_FLAG_ACCEPTED
              else
                ::Themis::Finals::Constants::SubmitResult::SUCCESS
              end

              ::Themis::Finals::Utils::EventEmitter.emit_log(
                4,
                attack_team_id: team.id,
                victim_team_id: flag.team_id,
                service_id: flag.service_id
              )
            end
          rescue ::Sequel::UniqueConstraintViolation => e
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_FLAG_SUBMITTED
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_SUBMITTED
            end
          end

          attempt.response = r
          attempt.save
          return r
        end

        def self.process(team, data)
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: ::DateTime.now,
            request: data.to_s,
            response: ::Themis::Finals::Constants::SubmitResult::ERROR_UNKNOWN,
            team_id: team.id,
            deprecated_api: false
          )

          internal_process(attempt, team, data)
        end

        def self.process_deprecated(team, data)
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: ::DateTime.now,
            request: data.to_s,
            response: ::Themis::Finals::Attack::Result::ERR_GENERIC,
            team_id: team.id,
            deprecated_api: true
          )

          threshold =
            ::Time.now -
            ::Themis::Finals::Configuration.get_deprecated_settings.attack_limit_period

          attempt_count = ::Themis::Finals::Models::AttackAttempt.where(
            team: team,
            deprecated_api: true
          ).where(
            'occured_at >= ?',
            threshold.to_datetime
          ).count

          limit_attempts = \
            ::Themis::Finals::Configuration.get_deprecated_settings.attack_limit_attempts

          if attempt_count > limit_attempts
            r = ::Themis::Finals::Attack::Result::ERR_ATTEMPTS_LIMIT
            attempt.response = r
            attempt.save
            return r
          end

          internal_process(attempt, team, data)
        end
      end
    end
  end
end
