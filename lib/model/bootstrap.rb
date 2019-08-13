require 'date'

module VolgaCTF
  module Final
    module Model
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

      require './lib/model/team'
      require './lib/model/service'
      require './lib/model/scoreboard_state'
      require './lib/model/competition_stage'
      require './lib/model/server_sent_event'
      require './lib/model/post'
      require './lib/model/round'
      require './lib/model/total_score'
      require './lib/model/team_service_push_history_state'
      require './lib/model/team_service_push_state'
      require './lib/model/team_service_pull_history_state'
      require './lib/model/team_service_pull_state'
      require './lib/model/score'
      require './lib/model/flag'
      require './lib/model/flag_poll'
      require './lib/model/attack_attempt'
      require './lib/model/attack'
      require './lib/model/scoreboard_position'
      require './lib/model/scoreboard_history_position'
      require './lib/model/poll'
      require './lib/model/configuration'

      def self.init
      end
    end
  end
end
