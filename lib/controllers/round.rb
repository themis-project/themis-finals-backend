require 'time_difference'

require './lib/utils/event_emitter'
require './lib/controllers/domain'

module VolgaCTF
  module Final
    module Controllers
      class Round
        def initialize
          @logger = ::VolgaCTF::Final::Utils::Logger.get
          @domain_ctrl = ::VolgaCTF::Final::Controllers::Domain.new
        end

        def last_number
          round = ::VolgaCTF::Final::Models::Round.last
          round.nil? ? 0 : round.id
        end

        def gap_filled?(cutoff)
          return false unless @domain_ctrl.available?

          round = ::VolgaCTF::Final::Models::Round.last
          return true if round.nil?

          duration = @domain_ctrl.settings.round_timespan
          diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds

          return diff > duration
        end

        def can_poll?(cutoff)
          return false unless @domain_ctrl.available?

          round = ::VolgaCTF::Final::Models::Round.last
          return false if round.nil?

          last_poll = ::VolgaCTF::Final::Models::Poll.last_relevant(round)
          if last_poll.nil?
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            return diff > @domain_ctrl.settings.poll_delay
          else
            diff = ::TimeDifference.between(last_poll.created_at, cutoff).in_seconds
            return diff > @domain_ctrl.settings.poll_timespan
          end
        end

        def last_round_finished?
          round = ::VolgaCTF::Final::Models::Round.last
          return !(round.nil? || round.finished_at.nil?)
        end

        def create_round
          round = nil
          round_number = nil
          ::VolgaCTF::Final::Models::DB.transaction do
            round = ::VolgaCTF::Final::Models::Round.create(
              started_at: ::DateTime.now
            )
            ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
              'competition/round',
              value: round.id
            )
            ::VolgaCTF::Final::Utils::EventEmitter.emit_log(
              2,
              value: round.id
            )

            ::VolgaCTF::Final::Models::DB.after_commit do
              @logger.info "Round #{round.id} started!"
            end
          end

          round
        end

        def create_poll
          round = ::VolgaCTF::Final::Models::Round.last
          poll = nil
          ::VolgaCTF::Final::Models::DB.transaction do
            poll = ::VolgaCTF::Final::Models::Poll.create(
              created_at: ::DateTime.now,
              round: round
            )
          end

          poll
        end

        def expired_rounds(cutoff)
          return [] unless @domain_ctrl.available?

          ::VolgaCTF::Final::Models::Round.current.all.select do |round|
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            next false if diff < @domain_ctrl.settings.round_timespan

            rel_flags = ::VolgaCTF::Final::Models::Flag.relevant(round)
            rel_expired_flags = ::VolgaCTF::Final::Models::Flag.relevant_expired(round, cutoff)
            next false if rel_flags.count > rel_expired_flags.count

            next true
          end
        end
      end
    end
  end
end
