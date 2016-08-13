require 'eventmachine'
require './lib/utils/queue'
require './lib/utils/logger'
require './lib/queue/tasks'

module Themis
  module Finals
    module Scheduler
      @logger = ::Themis::Finals::Utils::Logger.get

      def self.run
        contest_flow = ::Themis::Finals::Configuration.get_contest_flow
        ::EM.run do
          @logger.info 'Scheduler started, CTRL+C to stop'

          ::EM.add_periodic_timer contest_flow.push_period do
            ::Themis::Finals::Queue::Tasks::PushFlags.perform_async
          end

          ::EM.add_periodic_timer contest_flow.poll_period do
            ::Themis::Finals::Queue::Tasks::PollFlags.perform_async
          end

          ::EM.add_periodic_timer contest_flow.update_period do
            ::Themis::Finals::Queue::Tasks::UpdateScores.perform_async
          end

          ::Signal.trap 'INT' do
            ::EM.stop
          end

          ::Signal.trap 'TERM' do
            ::EM.stop
          end
        end

        @logger.info 'Received shutdown signal'
      end
    end
  end
end
