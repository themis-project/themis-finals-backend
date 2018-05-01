require 'redis'
require 'hiredis'
require './lib/utils/logger'

# TODO: Deal with Redis::ConnectionError exception

module Themis
  module Finals
    module Utils
      class Publisher
        def initialize
          @_client = nil
          @_logger = ::Themis::Finals::Utils::Logger.get
        end

        def publish(channel, message, max_retries = 3)
          attempt = 0
          begin
            if attempt == max_retries
              @_logger.error "Failed to publish message to channel <#{channel}>"
              return
            end

            ensure_connection
            @_client.publish channel, message
          rescue ::Redis::CannotConnectError => e
            wait_period = 2**attempt
            attempt += 1
            @_logger.warn "#{e}, retrying in #{wait_period}s (attempt "\
                          "#{attempt})"
            sleep wait_period
            retry
          end
        end

        protected
        def ensure_connection
          return unless @_client.nil?
          connection_params = {
            host: ENV['REDIS_HOST'] || '127.0.0.1',
            port: ENV['REDIS_PORT'].to_i || 6379,
            db: ENV['THEMIS_FINALS_STREAM_REDIS_DB'].to_i || 0
          }
          unless ENV.fetch('REDIS_PASSWORD', nil).nil?
            connection_params[:password] = ENV['REDIS_PASSWORD']
          end
          @_client = ::Redis.new(**connection_params)
        end
      end
    end
  end
end
