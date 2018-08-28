require 'sidekiq'

require './lib/models/bootstrap'
require './lib/utils/logger'
require './lib/controllers/competition_stage'
require './lib/controllers/competition'
require './lib/utils/logger'

logger = ::Themis::Finals::Utils::Logger.get

config_redis = {
  url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{ENV['THEMIS_FINALS_QUEUE_REDIS_DB']}"
}

unless ENV.fetch('REDIS_PASSWORD', nil).nil?
  config_redis[:password] = ENV['REDIS_PASSWORD']
end

::Sidekiq.default_worker_options = { 'retry' => 0 }

::Sidekiq.configure_server do |config|
  config.redis = config_redis

  config.on(:startup) do
    logger.info "Starting queue process, instance #{ENV['QUEUE_INSTANCE']}"
    require './config'
    ::Themis::Finals::Models.init
  end
  config.on(:quiet) do
    logger.info 'Got USR1, stopping further job processing...'
  end
  config.on(:shutdown) do
    logger.info 'Got TERM, shutting down process...'
  end
end

::Sidekiq.configure_client do |config|
  config.redis = config_redis
end

module Themis
  module Finals
    module Queue
      module Tasks
        class Planner
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            if competition_ctrl.can_trigger_round?
              ::Themis::Finals::Queue::Tasks::TriggerRound.perform_async
            end

            if competition_ctrl.can_poll?
              ::Themis::Finals::Queue::Tasks::TriggerPoll.perform_async
            end

            if competition_ctrl.can_recalculate?
              ::Themis::Finals::Queue::Tasks::TriggerRecalculate.perform_async
            end

            if competition_ctrl.can_pause?
              ::Themis::Finals::Queue::Tasks::TriggerPause.perform_async
            end

            if competition_ctrl.can_finish?
              ::Themis::Finals::Queue::Tasks::TriggerFinish.perform_async
            end
          end
        end

        class TriggerRound
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            competition_ctrl.trigger_round
          end
        end

        class TriggerPoll
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            competition_ctrl.trigger_poll
          end
        end

        class TriggerRecalculate
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            competition_ctrl.trigger_recalculate
          end
        end

        class TriggerPause
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            competition_ctrl.pause
          end
        end

        class TriggerFinish
          include ::Sidekiq::Worker

          def perform
            competition_ctrl = ::Themis::Finals::Controllers::Competition.new
            competition_ctrl.finish
          end
        end

        class PullFlag
          include ::Sidekiq::Worker

          def perform(flag_str)
            flag = ::Themis::Finals::Models::Flag.first(flag: flag_str)
            unless flag.nil?
              competition_ctrl = ::Themis::Finals::Controllers::Competition.new
              competition_ctrl.pull_flag(flag)
            end
          end
        end
      end
    end
  end
end
