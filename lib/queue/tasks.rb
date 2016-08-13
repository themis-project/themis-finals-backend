require 'sidekiq'
require './lib/models/init'
require './lib/utils/logger'
require './lib/controllers/contest'

::Sidekiq.configure_server do |config|
  config.redis = {
    url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/"\
         "#{ENV['THEMIS_FINALS_QUEUE_REDIS_DB']}"
  }

  config.on(:startup) do
    puts "Starting queue process, instance #{ENV['QUEUE_INSTANCE']}"
    require './config'
    ::Themis::Finals::Models.init
  end
  config.on(:quiet) do
    puts 'Got USR1, stopping further job processing...'
  end
  config.on(:shutdown) do
    puts 'Got TERM, shutting down process...'
  end
end

::Sidekiq.configure_client do |config|
  config.redis = {
    url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/"\
         "#{ENV['THEMIS_FINALS_QUEUE_REDIS_DB']}"
  }
end

module Themis
  module Finals
    module Queue
      module Tasks
        class UpdateScores
          include ::Sidekiq::Worker

          def perform
            logger = ::Themis::Finals::Utils::Logger.get
            contest_state = ::Themis::Finals::Models::ContestState.last
            if !contest_state.nil? && (contest_state.is_running ||
                                       contest_state.is_await_complete)
              begin
                ::Themis::Finals::Controllers::Contest.update_all_scores
              rescue => e
                logger.error e.to_s
              end
            end
          end
        end

        class PushFlags
          include ::Sidekiq::Worker

          def perform
            contest_state = ::Themis::Finals::Models::ContestState.last
            if !contest_state.nil? && (contest_state.is_await_start ||
                                       contest_state.is_running)
              if contest_state.is_await_start
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
            contest_state = ::Themis::Finals::Models::ContestState.last
            unless contest_state.nil?
              if contest_state.is_running || contest_state.is_await_complete
                ::Themis::Finals::Controllers::Contest.poll_flags
              elsif contest_state.is_paused
                ::Themis::Finals::Controllers::Contest.prolong_flag_lifetimes
              end
            end
          end
        end
      end
    end
  end
end
