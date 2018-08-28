require 'eventmachine'

require './lib/utils/logger'
require './lib/queue/tasks'

module Themis
  module Finals
    class Scheduler
      def initialize
        @logger = ::Themis::Finals::Utils::Logger.get
      end

      def run
        ::EM.run do
          @logger.info('Scheduler started, CTRL+C to stop')

          ::EM.add_periodic_timer 5 do
            ::Themis::Finals::Queue::Tasks::Planner.perform_async
          end

          ::Signal.trap 'INT' do
            ::EM.stop
          end

          ::Signal.trap 'TERM' do
            ::EM.stop
          end
        end

        @logger.info('Received shutdown signal')
      end
    end
  end
end
