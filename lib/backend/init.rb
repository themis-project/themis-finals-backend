require 'thin'
require 'eventmachine'
require './lib/backend/application'
require './lib/utils/logger'


module Themis
    module Backend
        @logger = Themis::Utils::Logger::get

        def self.run
            EM.run do
                port = ENV['PORT_RANGE_START'].to_i + ENV['APP_INSTANCE'].to_i
                Thin::Server.start Application, ENV['HOST'], port

                Signal.trap 'INT' do
                    EM.stop
                end

                Signal.trap 'TERM' do
                    EM.stop
                end
            end

            @logger.info 'Received shutdown signal'
        end
    end
end
