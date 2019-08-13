require 'time_difference'

require './lib/util/event_emitter'
require './lib/controller/domain'

module VolgaCTF
  module Final
    module Controller
      class Round
        def initialize
          @logger = ::VolgaCTF::Final::Util::Logger.get
          @domain_ctrl = ::VolgaCTF::Final::Controller::Domain.new
        end

        def last_number
          round = ::VolgaCTF::Final::Model::Round.last
          round.nil? ? 0 : round.id
        end

        def gap_filled?(cutoff)
          return false unless @domain_ctrl.available?

          round = ::VolgaCTF::Final::Model::Round.last
          return true if round.nil?

          duration = @domain_ctrl.settings.round_timespan
          diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds

          return diff > duration
        end

        def can_poll?(cutoff)
          return false unless @domain_ctrl.available?

          round = ::VolgaCTF::Final::Model::Round.last
          return false if round.nil?

          last_poll = ::VolgaCTF::Final::Model::Poll.last_relevant(round)
          if last_poll.nil?
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            return diff > @domain_ctrl.settings.poll_delay
          else
            diff = ::TimeDifference.between(last_poll.created_at, cutoff).in_seconds
            return diff > @domain_ctrl.settings.poll_timespan
          end
        end

        def last_round_finished?
          round = ::VolgaCTF::Final::Model::Round.last
          return !(round.nil? || round.finished_at.nil?)
        end

        def create_round
          round = nil
          round_number = nil
          ::VolgaCTF::Final::Model::DB.transaction do
            round = ::VolgaCTF::Final::Model::Round.create(
              started_at: ::DateTime.now
            )
            ::VolgaCTF::Final::Util::EventEmitter.broadcast(
              'competition/round',
              value: round.id
            )
            ::VolgaCTF::Final::Util::EventEmitter.emit_log(
              2,
              value: round.id
            )

            ::VolgaCTF::Final::Model::DB.after_commit do
              @logger.info "Round #{round.id} started!"
            end
          end

          round
        end

        def create_poll
          round = ::VolgaCTF::Final::Model::Round.last
          poll = nil
          ::VolgaCTF::Final::Model::DB.transaction do
            poll = ::VolgaCTF::Final::Model::Poll.create(
              created_at: ::DateTime.now,
              round: round
            )
          end

          poll
        end

        def expired_rounds(cutoff)
          return [] unless @domain_ctrl.available?

          ::VolgaCTF::Final::Model::Round.current.all.select do |round|
            diff = ::TimeDifference.between(round.started_at, cutoff).in_seconds
            next false if diff < @domain_ctrl.settings.round_timespan

            rel_flags = ::VolgaCTF::Final::Model::Flag.relevant(round)
            rel_expired_flags = ::VolgaCTF::Final::Model::Flag.relevant_expired(round, cutoff)
            next false if rel_flags.count > rel_expired_flags.count

            next true
          end
        end
      end
    end
  end
end
