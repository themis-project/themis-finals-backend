require 'date'

require 'themis/finals/attack/result'

require './lib/controllers/round'
require './lib/controllers/team_service_state'
require './lib/utils/event_emitter'
require './lib/constants/submit_result'
require './lib/controllers/domain'

module Themis
  module Finals
    module Controllers
      class Attack
        def initialize
          @domain_ctrl = ::Themis::Finals::Controllers::Domain.new
          @team_service_state_ctrl = ::Themis::Finals::Controllers::TeamServiceState.new
          @round_ctrl = ::Themis::Finals::Controllers::Round.new
        end

        def handle(team, data)
          cutoff = ::DateTime.now
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: cutoff,
            request: data.to_s,
            response: ::Themis::Finals::Constants::SubmitResult::ERROR_UNKNOWN,
            team_id: team.id,
            deprecated_api: false
          )

          internal_process(cutoff, attempt, team, data)
        end

        def handle_deprecated(team, data)
          cutoff = ::DateTime.now
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: cutoff,
            request: data.to_s,
            response: ::Themis::Finals::Attack::Result::ERR_GENERIC,
            team_id: team.id,
            deprecated_api: true
          )

          unless @domain_ctrl.available?
            attempt.save
            return ::Themis::Finals::Attack::Result::ERR_GENERIC
          end

          threshold = (cutoff.to_time - @domain_ctrl.deprecated_settings.attack_limit_period).to_datetime

          attempt_count = ::Themis::Finals::Models::AttackAttempt
          .where(team: team, deprecated_api: true)
          .where { occured_at >= threshold }
          .count

          if attempt_count > @domain_ctrl.deprecated_settings.attack_limit_attempts
            r = ::Themis::Finals::Attack::Result::ERR_ATTEMPTS_LIMIT
            attempt.response = r
            attempt.save
            return r
          end

          internal_process(cutoff, attempt, team, data)
        end

        private
        def internal_process(cutoff, attempt, team, data)
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

          flag = ::Themis::Finals::Models::Flag.first_match(match_[0])

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

          unless @team_service_state_ctrl.up?(team, flag.service)
            r = if old_code
              ::Themis::Finals::Attack::Result::ERR_SERVICE_NOT_UP
            else
              ::Themis::Finals::Constants::SubmitResult::ERROR_SERVICE_STATE_INVALID
            end
            attempt.response = r
            attempt.save
            return r
          end

          if flag.expired_at < cutoff
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
                occured_at: cutoff,
                processed: false,
                team_id: team.id,
                flag_id: flag.id
              )

              if flag.service.attack_priority && flag.service.award_defence_after.nil?
                flag.service.award_defence_after = @round_ctrl.last_number
                flag.service.save

                ::Themis::Finals::Utils::EventEmitter.broadcast(
                  'service/modify',
                  flag.service.serialize
                )

                ::Themis::Finals::Utils::EventEmitter.emit_log(
                  45,
                  service_name: flag.service.name,
                  service_award_defence_after: flag.service.award_defence_after
                )

              end

              r = if old_code
                ::Themis::Finals::Attack::Result::SUCCESS_FLAG_ACCEPTED
              else
                ::Themis::Finals::Constants::SubmitResult::SUCCESS
              end

              ::Themis::Finals::Utils::EventEmitter.emit_log(
                4,
                actor_team_id: team.id,
                target_team_id: flag.team_id,
                target_service_id: flag.service_id
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
      end
    end
  end
end
