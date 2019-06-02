require 'date'

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

        def handle(stage, team, data)
          cutoff = ::DateTime.now
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: cutoff,
            request: data.to_s,
            response: ::Themis::Finals::Constants::SubmitResult::ERROR_UNKNOWN,
            team_id: team.id
          )

          unless data.respond_to?('match')
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID
            attempt.response = r
            attempt.save
            return r
          end

          match_ = data.match(/^[\da-f]{32}=$/)
          if match_.nil?
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID
            attempt.response = r
            attempt.save
            return r
          end

          flag = ::Themis::Finals::Models::Flag.first_match(match_[0])

          if flag.nil?
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_NOT_FOUND
            attempt.response = r
            attempt.save
            return r
          end

          if flag.team_id == team.id
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_YOUR_OWN
            attempt.response = r
            attempt.save
            return r
          end

          unless @team_service_state_ctrl.up?(stage, team, flag.service)
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_SERVICE_STATE_INVALID
            attempt.response = r
            attempt.save
            return r
          end

          if flag.expired_at < cutoff
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_EXPIRED
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

              r = ::Themis::Finals::Constants::SubmitResult::SUCCESS

              ::Themis::Finals::Utils::EventEmitter.emit_log(
                4,
                actor_team_id: team.id,
                target_team_id: flag.team_id,
                target_service_id: flag.service_id
              )
            end
          rescue ::Sequel::UniqueConstraintViolation => e
            r = ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_SUBMITTED
          end

          attempt.response = r
          attempt.save
          return r
        end
      end
    end
  end
end
