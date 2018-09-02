require 'date'

module Themis
  module Finals
    module Models
      require 'sequel'

      connection_params = {
        adapter: 'postgres',
        host: ::ENV['PG_HOST'],
        port: ::ENV['PG_PORT'].to_i,
        user: ::ENV['PG_USERNAME'],
        password: ::ENV['PG_PASSWORD'],
        database: ::ENV['PG_DATABASE']
      }

      ::Sequel.datetime_class = ::DateTime
      DB = ::Sequel.connect(connection_params)
      DB.extension :pg_json

      require './lib/models/team'
      require './lib/models/service'
      require './lib/models/scoreboard_state'
      require './lib/models/competition_stage'
      require './lib/models/server_sent_event'
      require './lib/models/post'
      require './lib/models/round'
      require './lib/models/total_score'
      require './lib/models/team_service_push_history_state'
      require './lib/models/team_service_push_state'
      require './lib/models/team_service_pull_history_state'
      require './lib/models/team_service_pull_state'
      require './lib/models/score'
      require './lib/models/flag'
      require './lib/models/flag_poll'
      require './lib/models/attack_attempt'
      require './lib/models/attack'
      require './lib/models/scoreboard_position'
      require './lib/models/scoreboard_history_position'
      require './lib/models/poll'

      def self.init
      end
    end
  end
end
