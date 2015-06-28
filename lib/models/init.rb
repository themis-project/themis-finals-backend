module Themis
    module Models
        def self.init
            require 'data_mapper'

            DataMapper::Logger.new $stdout, :info
            DataMapper::setup :default, ENV['DATABASE_URI']

            require './lib/models/team'
            require './lib/models/service'
            require './lib/models/score'
            require './lib/models/round'
            require './lib/models/attack-attempt'
            require './lib/models/attack'
            require './lib/models/flag'
            require './lib/models/calculated-score'
            require './lib/models/service-state'
            require './lib/models/realtime-service-state'
            require './lib/models/flag-poll'

            DataMapper::finalize
        end
    end
end
