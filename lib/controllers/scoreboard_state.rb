require './lib/utils/event_emitter'
require './lib/controllers/scoreboard'

module Themis
  module Finals
    module Controllers
      module ScoreboardState
        def self.is_enabled
          scoreboard_state = ::Themis::Finals::Models::ScoreboardState.last
          return scoreboard_state.nil? ? true : scoreboard_state.enabled
        end

        def self.enable
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardState.create(
              enabled: true,
              created_at: ::DateTime.now
            )

            formatted_positions = \
              ::Themis::Finals::Controllers::Scoreboard.format_team_positions(
                ::Themis::Finals::Controllers::Scoreboard.get_team_positions
              )

            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: ::DateTime.now,
              data: formatted_positions
            )

            data = {
              muted: false,
              positions: formatted_positions
            }

            ::Themis::Finals::Utils::EventEmitter.broadcast(
              'scoreboard',
              data
            )
          end
        end

        def self.disable
          ::Themis::Finals::Models::DB.transaction do
            ::Themis::Finals::Models::ScoreboardState.create(
              enabled: false,
              created_at: ::DateTime.now
            )

            formatted_positions = \
              ::Themis::Finals::Controllers::Scoreboard.format_team_positions(
                ::Themis::Finals::Controllers::Scoreboard.get_team_positions
              )

            ::Themis::Finals::Models::ScoreboardHistoryPosition.create(
              created_at: ::DateTime.now,
              data: formatted_positions
            )

            ::Themis::Finals::Models::ScoreboardPosition.create(
              created_at: ::DateTime.now,
              data: formatted_positions
            )

            ::Themis::Finals::Utils::EventEmitter.emit(
              'scoreboard',
              {
                muted: false,
                positions: formatted_positions
              },
              true,
              false,
              false
            )

            ::Themis::Finals::Utils::EventEmitter.emit(
              'scoreboard',
              {
                muted: true,
                positions: formatted_positions
              },
              false,
              true,
              true
            )
          end
        end
      end
    end
  end
end
