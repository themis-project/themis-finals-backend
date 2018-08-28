require 'time_difference'

require './lib/utils/event_emitter'

module Themis
  module Finals
    module Controllers
      class Round
        def initialize
          @logger = ::Themis::Finals::Utils::Logger.get
          @settings = ::Themis::Finals::Configuration.get_settings
        end

        def gap_filled?(cutoff)
          round = ::Themis::Finals::Models::Round.last
          return true if round.nil?

          duration = @settings.round_timespan
          diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds

          return diff > duration
        end

        def can_poll?(cutoff)
          round = ::Themis::Finals::Models::Round.last
          return false if round.nil?

          last_poll = ::Themis::Finals::Models::Poll.last_relevant(round)
          if last_poll.nil?
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            return diff > @settings.poll_delay
          else
            diff = ::TimeDifference.between(last_poll.created_at, cutoff).in_seconds
            return diff > @settings.poll_timespan
          end
        end

        def last_round_finished?
          round = ::Themis::Finals::Models::Round.last
          return !(round.nil? || round.finished_at.nil?)
        end

        def create_round
          round = nil
          round_number = nil
          ::Themis::Finals::Models::DB.transaction do
            round = ::Themis::Finals::Models::Round.create(
              started_at: ::DateTime.now
            )
            ::Themis::Finals::Utils::EventEmitter.broadcast(
              'competition/round',
              value: round.id
            )
            ::Themis::Finals::Utils::EventEmitter.emit_log(
              2,
              value: round.id
            )

            ::Themis::Finals::Models::DB.after_commit do
              @logger.info "Round #{round.id} started!"
            end
          end

          round
        end

        def create_poll
          round = ::Themis::Finals::Models::Round.last
          poll = nil
          ::Themis::Finals::Models::DB.transaction do
            poll = ::Themis::Finals::Models::Poll.create(
              created_at: ::DateTime.now,
              round: round
            )
          end

          poll
        end

        def expired_rounds(cutoff)
          ::Themis::Finals::Models::Round.current.all.select do |round|
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            next false if diff < @settings.round_timespan

            rel_flags = ::Themis::Finals::Models::Flag.relevant(round)
            rel_expired_flags = ::Themis::Finals::Models::Flag.relevant_expired(round, cutoff)
            next false if rel_flags.count > rel_expired_flags.count

            next true
          end
        end
      end
    end
  end
end
