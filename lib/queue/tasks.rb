require 'sidekiq'
require './lib/models/bootstrap'
require './lib/utils/logger'
require './lib/controllers/contest'
require './lib/controllers/competition_stage'
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
        class UpdateScores
          include ::Sidekiq::Worker

          def perform
            logger = ::Themis::Finals::Utils::Logger.get
            stage = ::Themis::Finals::Controllers::CompetitionStage.new.current
            if stage.started? || stage.finishing?
              begin
                ::Themis::Finals::Controllers::Contest.update_all_scores
              rescue => e
                logger.error(e.to_s)
              end
            end
          end
        end

        class PushFlags
          include ::Sidekiq::Worker

          def perform
            stage = ::Themis::Finals::Controllers::CompetitionStage.new.current
            if stage.starting? || stage.started?
              if stage.starting?
                ::Themis::Finals::Controllers::Contest.start
              end
              ::Themis::Finals::Controllers::Contest.push_flags
            end
          end
        end

        class PullFlag
          include ::Sidekiq::Worker

          def perform(flag_str)
            flag = ::Themis::Finals::Models::Flag.first(flag: flag_str)
            unless flag.nil?
              ::Themis::Finals::Controllers::Contest.poll_flag flag
            end
          end
        end

        class PollFlags
          include ::Sidekiq::Worker

          def perform
            stage = ::Themis::Finals::Controllers::CompetitionStage.new.current
            if stage.started? || stage.finishing?
              ::Themis::Finals::Controllers::Contest.poll_flags
            elsif stage.paused?
              ::Themis::Finals::Controllers::Contest.prolong_flag_lifetimes
            end
          end
        end
      end
    end
  end
end
