require './lib/controllers/scoreboard_state'
require './lib/utils/event_emitter'
require './lib/constants/contest_state'
require 'json'

module Themis
  module Finals
    module Controllers
      module ContestState
        def self.init
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Configuration.get_teams.each do |team_opts|
              ::Themis::Finals::Models::Team.create(
                name: team_opts.name,
                alias: team_opts.alias,
                network: team_opts.network,
                host: team_opts.host,
                guest: team_opts.guest
              )
            end

            ::Themis::Finals::Configuration.get_services.each do |service_opts|
              ::Themis::Finals::Models::Service.create(
                name: service_opts.name,
                alias: service_opts.alias,
                protocol: service_opts.protocol,
                metadata: service_opts.metadata
              )
            end

            change_state ::Themis::Finals::Constants::ContestState::INITIAL
            ::Themis::Finals::Controllers::ScoreboardState.enable

            ::Themis::Finals::Models::DB.after_commit do
              stream_config_filename = ::File.join(::Dir.pwd, '..', 'stream',
                                                   'config.json')
              data = ::Themis::Finals::Configuration.get_stream_config
              ::IO.write stream_config_filename, ::JSON.pretty_generate(data)
            end
          end
        end

        def self.start_async
          change_state ::Themis::Finals::Constants::ContestState::AWAIT_START
        end

        def self.start
          change_state ::Themis::Finals::Constants::ContestState::RUNNING
        end

        def self.resume
          change_state ::Themis::Finals::Constants::ContestState::RUNNING
        end

        def self.pause
          change_state ::Themis::Finals::Constants::ContestState::PAUSED
        end

        def self.complete_async
          change_state ::Themis::Finals::Constants::ContestState::AWAIT_COMPLETE
        end

        def self.complete
          change_state ::Themis::Finals::Constants::ContestState::COMPLETED
        end

        private
        def self.change_state(state)
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ContestState.create(
              state: state,
              created_at: ::DateTime.now
            )

            ::Themis::Finals::Utils::EventEmitter.emit_all(
              'contest/state',
              { value: state }
            )
            ::Themis::Finals::Utils::EventEmitter.emit_log 1, { value: state }
          end
        end
      end
    end
  end
end
