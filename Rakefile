require 'dotenv'
::Dotenv.load
require 'optparse'

namespace :db do
  desc 'Clear database'
  task :reset do
    require 'rubygems'
    require 'sequel'

    connection_params = {
      adapter: 'postgres',
      host: ::ENV['PG_HOST'],
      port: ::ENV['PG_PORT'].to_i,
      user: ::ENV['PG_USERNAME'],
      password: ::ENV['PG_PASSWORD'],
      database: ::ENV['PG_DATABASE']
    }

    ::Sequel.connect(connection_params) do |db|
      %w(
        configurations
        scoreboard_positions
        scoreboard_history_positions
        server_sent_events
        competition_stages
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
        polls
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

    puts 'OK'
  end
end

def change_competition_stage(command)
  require './lib/models/bootstrap'
  require './lib/controllers/competition'

  ::Themis::Finals::Models.init
  competition_ctrl = ::Themis::Finals::Controllers::Competition.new

  case command
  when :init
    competition_ctrl.init
  when :start
    competition_ctrl.enqueue_start
  when :resume
    competition_ctrl.enqueue_start
  when :pause
    competition_ctrl.enqueue_pause
  when :finish
    competition_ctrl.enqueue_finish
  end

  puts 'OK'
end

namespace :competition do
  desc 'Init competition'
  task :init, [:domain] do |_, args|
    require './lib/domain/init'
    require args[:domain]
    change_competition_stage(:init)
  end

  desc 'Enqueue start competition'
  task :start do
    change_competition_stage(:start)
  end

  desc 'Resume competition'
  task :resume do
    change_competition_stage :resume
  end

  desc 'Enqueue pause competition'
  task :pause do
    change_competition_stage :pause
  end

  desc 'Enqueue finish competition'
  task :finish do
    change_competition_stage(:finish)
  end
end

def change_scoreboard_state(state)
  require './lib/models/bootstrap'
  require './lib/controllers/scoreboard'

  ::Themis::Finals::Models.init
  scoreboard_ctrl = ::Themis::Finals::Controllers::Scoreboard.new

  case state
  when :enabled
    scoreboard_ctrl.enable_broadcast
  when :disabled
    scoreboard_ctrl.disable_broadcast
  end
end

namespace :scoreboard do
  desc 'Enable scoreboard (for team and external networks)'
  task :enable do
    change_scoreboard_state(:enabled)
  end

  desc 'Disable scoreboard (for team and external networks)'
  task :disable do
    change_scoreboard_state(:disabled)
  end
end

namespace :service do
  desc 'Initialize a new service from domain file'
  task :init, [:domain] do |_, args|
    require './lib/domain/init'
    require args[:domain]
    require './lib/models/bootstrap'
    require './lib/controllers/domain'

    ::Themis::Finals::Models.init
    domain_ctrl = ::Themis::Finals::Controllers::Domain.new
    domain_ctrl.update
    puts 'OK'
  end

  desc 'Disable a service in a certain round'
  task :disable, [:alias, :round] do |_, args|
    require './lib/domain/init'
    require './lib/models/bootstrap'
    require './lib/controllers/service'

    ::Themis::Finals::Models.init
    service_ctrl = ::Themis::Finals::Controllers::Service.new
    service_ctrl.enqueue_disable(args[:alias], args[:round].to_i)
    puts 'OK'
  end

  desc 'Enable a service in a certain round'
  task :enable, [:alias, :round] do |_, args|
    require './lib/domain/init'
    require './lib/models/bootstrap'
    require './lib/controllers/service'

    ::Themis::Finals::Models.init
    service_ctrl = ::Themis::Finals::Controllers::Service.new
    service_ctrl.enqueue_enable(args[:alias], args[:round].to_i)
    puts 'OK'
  end
end

namespace :report do
  desc 'Show global stats'
  task :global_stats do
    require './lib/models/bootstrap'
    require 'terminal-table'
    require 'time_difference'
    require 'active_support/time'

    ::Themis::Finals::Models.init
    ::Time.zone = 'Europe/Samara'

    rows = []

    num_teams = ::Themis::Finals::Models::Team.count
    rows << ['Number of teams', num_teams]

    num_services = ::Themis::Finals::Models::Service.count
    rows << ['Number of services', num_services]

    num_rounds = ::Themis::Finals::Models::Round.count
    rows << ['Number of rounds', num_rounds]

    contest_started = nil
    contest_ended = nil

    ::Themis::Finals::Models::CompetitionStage.all.each do |entry|
      if contest_started.nil? && entry.started?
        contest_started = entry.created_at
      end

      if contest_ended.nil? && entry.finished?
        contest_ended = entry.created_at
      end
    end

    unless contest_started.nil? || contest_ended.nil?
      cell = []
      cell << ::TimeDifference.between(contest_started, contest_ended).humanize
      cell << "from #{contest_started.in_time_zone}"
      cell << "till #{contest_ended.in_time_zone}"
      rows << ["Contest duration", cell.join("\n")]
    end

    table = ::Terminal::Table.new(
      headings: ['Parameter', 'Value'],
      rows: rows,
      style: {
        all_separators: true
      }
    )

    puts table
  end

  desc 'Show flag stats'
  task :flag_stats do
    require './lib/models/bootstrap'
    require './lib/constants/team_service_state'
    require 'terminal-table'
    require 'time_difference'
    require 'active_support/time'

    ::Themis::Finals::Models.init
    ::Time.zone = 'Europe/Samara'

    rows = []

    num_issued_flags = ::Themis::Finals::Models::Flag.count
    rows << ['Issued flags', num_issued_flags]

    num_push_attempts_up = ::Themis::Finals::Models::TeamServicePushHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::UP).count
    num_push_attempts_up_rel = Float(num_push_attempts_up) * 100 / num_issued_flags
    rows << ['Number of successful push attempts', "#{num_push_attempts_up} (#{num_push_attempts_up_rel.round(2)}%)"]

    num_push_attempts_down = ::Themis::Finals::Models::TeamServicePushHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::DOWN).count
    num_push_attempts_down_rel = Float(num_push_attempts_down) * 100 / num_issued_flags

    num_push_attempts_mumble = ::Themis::Finals::Models::TeamServicePushHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::MUMBLE).count
    num_push_attempts_mumble_rel = Float(num_push_attempts_mumble) * 100 / num_issued_flags

    num_push_attempts_na = num_issued_flags - num_push_attempts_up - num_push_attempts_down - num_push_attempts_mumble
    num_push_attempts_na_rel = Float(num_push_attempts_na) * 100 / num_issued_flags

    num_push_attempts_failed = num_issued_flags - num_push_attempts_up
    num_push_attempts_failed_rel = Float(num_push_attempts_failed) * 100 / num_issued_flags
    push_attempts_failed_text = []
    push_attempts_failed_text << "#{num_push_attempts_failed} (#{num_push_attempts_failed_rel.round(2)}%)"
    push_attempts_failed_text << " DOWN #{num_push_attempts_down} (#{num_push_attempts_down_rel.round(2)}%)"
    push_attempts_failed_text << " MUMBLE #{num_push_attempts_mumble} (#{num_push_attempts_mumble_rel.round(2)}%)"
    push_attempts_failed_text << " N/A #{num_push_attempts_na} (#{num_push_attempts_na_rel.round(2)}%)"
    rows << ['Number of failed push attempts', push_attempts_failed_text.join("\n")]

    num_pull_attempts = ::Themis::Finals::Models::TeamServicePullHistoryState.count
    rows << ['Number of pull attempts', num_pull_attempts]

    num_pull_attempts_up = ::Themis::Finals::Models::TeamServicePullHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::UP).count
    num_pull_attempts_up_rel = Float(num_pull_attempts_up) * 100 / num_pull_attempts
    rows << ['Number of successful pull attempts', "#{num_pull_attempts_up} (#{num_pull_attempts_up_rel.round(2)}%)"]

    num_pull_attempts_failed = ::Themis::Finals::Models::TeamServicePullHistoryState.exclude(state: ::Themis::Finals::Constants::TeamServiceState::UP).count
    num_pull_attempts_failed_rel = Float(num_pull_attempts_failed) * 100 / num_pull_attempts
    pull_attempts_failed_text = []
    pull_attempts_failed_text << "#{num_pull_attempts_failed} (#{num_pull_attempts_failed_rel.round(2)}%)"

    num_pull_attempts_down = ::Themis::Finals::Models::TeamServicePullHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::DOWN).count
    num_pull_attempts_down_rel = Float(num_pull_attempts_down) * 100 / num_pull_attempts
    pull_attempts_failed_text << " DOWN #{num_pull_attempts_down} (#{num_pull_attempts_down_rel.round(2)}%)"

    num_pull_attempts_corrupt = ::Themis::Finals::Models::TeamServicePullHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::CORRUPT).count
    num_pull_attempts_corrupt_rel = Float(num_pull_attempts_corrupt) * 100 / num_pull_attempts
    pull_attempts_failed_text << " CORRUPT #{num_pull_attempts_corrupt} (#{num_pull_attempts_corrupt_rel.round(2)}%)"

    num_pull_attempts_mumble = ::Themis::Finals::Models::TeamServicePullHistoryState.where(state: ::Themis::Finals::Constants::TeamServiceState::MUMBLE).count
    num_pull_attempts_mumble_rel = Float(num_pull_attempts_mumble) * 100 / num_pull_attempts
    pull_attempts_failed_text << " MUMBLE #{num_pull_attempts_mumble} (#{num_pull_attempts_mumble_rel.round(2)}%)"

    rows << ['Number of failed pull attempts', pull_attempts_failed_text.join("\n")]

    table = ::Terminal::Table.new(
      headings: ['Parameter', 'Value'],
      rows: rows,
      style: {
        all_separators: true
      }
    )

    puts table
  end


  desc 'Show attack stats'
  task :attack_stats do
    require './lib/models/bootstrap'
    # require './lib/constants/team_service_state'
    require 'terminal-table'
    require 'active_support/time'
    require 'themis/finals/attack/result'

    ::Themis::Finals::Models.init
    ::Time.zone = 'Europe/Samara'

    rows = []

    num_attack_attempts = ::Themis::Finals::Models::AttackAttempt.count
    rows << ['Number of attack attempts', num_attack_attempts]

    num_attacks = ::Themis::Finals::Models::Attack.count
    num_attacks_rel = Float(num_attacks) * 100 / num_attack_attempts
    rows << ['Number of successful attacks', "#{num_attacks} (#{num_attacks_rel.round(2)}%)"]

    failed_categories = {
      ::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT => 'ERR_INVALID_FORMAT',
      ::Themis::Finals::Attack::Result::ERR_ATTEMPTS_LIMIT => 'ERR_ATTEMPTS_LIMIT',
      ::Themis::Finals::Attack::Result::ERR_FLAG_EXPIRED => 'ERR_FLAG_EXPIRED',
      ::Themis::Finals::Attack::Result::ERR_FLAG_YOURS => 'ERR_FLAG_YOURS',
      ::Themis::Finals::Attack::Result::ERR_FLAG_SUBMITTED => 'ERR_FLAG_SUBMITTED',
      ::Themis::Finals::Attack::Result::ERR_FLAG_NOT_FOUND => 'ERR_FLAG_NOT_FOUND',
      ::Themis::Finals::Attack::Result::ERR_SERVICE_NOT_UP => 'ERR_SERVICE_NOT_UP'
    }

    failed_categories.each do |category, description|
      absolute_value = ::Themis::Finals::Models::AttackAttempt.where(response: category).count
      relative_value = Float(absolute_value) * 100 / num_attack_attempts
      rows << [
        "Number of failed attack attempts (#{description})",
        "#{absolute_value} (#{relative_value.round(2)}%)"
      ]
    end

    table = ::Terminal::Table.new(
      headings: ['Parameter', 'Value'],
      rows: rows,
      style: {
        all_separators: true
      }
    )

    puts table
  end

  desc 'Show services which have been attacked by teams'
  task :team_services do
    require './lib/models/bootstrap'
    ::Themis::Finals::Models.init

    report = {}

    ::Themis::Finals::Models::Team.all.each do |team|
      report[team.id] = Set.new
    end

    ::Themis::Finals::Models::Attack.all.each do |attack|
      flag = ::Themis::Finals::Models::Flag[attack.flag_id]
      report[attack.team_id].add(flag.service_id)
    end

    require 'terminal-table'
    rows = []
    report.each do |team_id, service_list|
      row = []
      row << ::Themis::Finals::Models::Team[team_id].name
      services = service_list.map do |service_id|
        ::Themis::Finals::Models::Service[service_id].name
      end
      row << services.join("\n")
      rows << row
    end

    table = ::Terminal::Table.new(
      headings: ['Team', 'Services'],
      rows: rows,
      style: {
        all_separators: true
      }
    )

    puts table
  end
end
