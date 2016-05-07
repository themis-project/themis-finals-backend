module Themis
    module Models
        require 'sequel'

        connection_params = {
            :adapter => 'postgres',
            :host => ENV['PG_HOST'],
            :port => ENV['PG_PORT'].to_i,
            :user => ENV['PG_USERNAME'],
            :password => ENV['PG_PASSWORD'],
            :database => ENV['PG_DATABASE']
        }

        DB = Sequel.connect(connection_params)
        DB.extension :pg_json

        require './lib/models/team'
        require './lib/models/service'
        require './lib/models/scoreboard-state'
        require './lib/models/contest-state'
        require './lib/models/server-sent-event'
        require './lib/models/post'
        require './lib/models/round'
        require './lib/models/total-score'
        require './lib/models/team-service-history-state'
        require './lib/models/team-service-state'
        require './lib/models/score'
        require './lib/models/flag'
        require './lib/models/flag-poll'
        require './lib/models/attack-attempt'
        require './lib/models/attack'

        def self.init
        end
    end
end
