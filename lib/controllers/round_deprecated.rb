require './lib/utils/event_emitter'

module Themis
  module Finals
    module Controllers
      module RoundDeprecated
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.start_new
          round = nil
          round_number = nil
          ::Themis::Finals::Models::DB.transaction do
            # end_last
            round = ::Themis::Finals::Models::Round.create(
              started_at: ::DateTime.now
            )
            round_number = ::Themis::Finals::Models::Round.count
            ::Themis::Finals::Utils::EventEmitter.broadcast(
              'competition/round',
              value: round_number
            )
            ::Themis::Finals::Utils::EventEmitter.emit_log(
              2,
              value: round_number
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info "Round #{round_number} started!"
            end
          end

          round
        end

        def self.end_last
          round_number = nil
          ::Themis::Finals::Models::DB.transaction do
            current_round = ::Themis::Finals::Models::Round.last
            unless current_round.nil?
              current_round.finished_at = ::DateTime.now
              current_round.save
              round_number = ::Themis::Finals::Models::Round.count
            end

            ::Themis::Finals::Models::DB.after_commit do
              unless round_number.nil?
                @logger.info "Round #{round_number} finished!"
              end
            end
          end
        end
      end
    end
  end
end
