require 'dotenv'
::Dotenv.load

namespace :db do
  desc 'Clear database'
  task :reset do
    require 'rubygems'
    require './config'
    require 'sequel'

    connection_params = {
      adapter: 'postgres',
      host: ENV['PG_HOST'],
      port: ENV['PG_PORT'].to_i,
      user: ENV['PG_USERNAME'],
      password: ENV['PG_PASSWORD'],
      database: ENV['PG_DATABASE']
    }

    ::Sequel.connect(connection_params) do |db|
      %w(
        scoreboard_positions
        scoreboard_history_positions
        server_sent_events
        contest_states
        posts
        scoreboard_states
        attack_attempts
        attacks
        total_scores
        scores
        team_service_push_history_states
        team_service_push_states
        team_service_pull_history_states
        team_service_pull_states
        flag_polls
        flags
        rounds
        services
        teams
        schema_info
      ).each do |table|
        db.run "DROP TABLE IF EXISTS #{table}"
      end
    end

    ::Sequel.extension :migration
    ::Sequel.extension :pg_json

    ::Sequel.connect(connection_params) do |db|
      ::Sequel::Migrator.run(db, 'migrations')
    end
  end
end

def change_contest_state(command)
  require './config'
  require './lib/models/init'
  require './lib/controllers/contest_state'

  ::Themis::Finals::Models.init

  case command
  when :init
    ::Themis::Finals::Controllers::ContestState.init
  when :start_async
    ::Themis::Finals::Controllers::ContestState.start_async
  when :resume
    ::Themis::Finals::Controllers::ContestState.resume
  when :pause
    ::Themis::Finals::Controllers::ContestState.pause
  when :complete_async
    ::Themis::Finals::Controllers::ContestState.complete_async
  end
end

def estimate_completion
  require './config'
  require './lib/models/init'

  ::Themis::Finals::Models.init
  max_expired_at = ::Themis::Finals::Models::Flag.all_living.max :expired_at
  approx_delay = ::Themis::Finals::Configuration.get_contest_flow.update_period
  if max_expired_at.nil?
      approx_end = ::DateTime.now
  else
      approx_end = max_expired_at
  end

  puts "Approximately at #{approx_end} + ~#{approx_delay}s"
end

namespace :contest do
  desc 'Init contest'
  task :init do
    change_contest_state :init
  end

  desc 'Enqueue start contest'
  task :start_async do
    change_contest_state :start_async
  end

  desc 'Resume contest'
  task :resume do
    change_contest_state :resume
  end

  desc 'Pause contest'
  task :pause do
    change_contest_state :pause
  end

  desc 'Enqueue complete contest'
  task :complete_async do
    change_contest_state :complete_async
  end

  desc 'Estimate contest completion time'
  task :estimate_completion do
    estimate_completion
  end
end

def change_scoreboard_state(state)
  require './config'
  require './lib/models/init'
  require './lib/controllers/scoreboard_state'

  ::Themis::Finals::Models.init

  case state
  when :enabled
    ::Themis::Finals::Controllers::ScoreboardState.enable
  when :disabled
    ::Themis::Finals::Controllers::ScoreboardState.disable
  end
end

namespace :scoreboard do
  desc 'Enable scoreboard (for team and external networks)'
  task :enable do
    change_scoreboard_state :enabled
  end

  desc 'Disable scoreboard (for team and external networks)'
  task :disable do
    change_scoreboard_state :disabled
  end
end
