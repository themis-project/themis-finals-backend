require 'date'

require 'themis/finals/checker/result'

require './lib/constants/team_service_state'
require './lib/utils/event_emitter'

module Themis
  module Finals
    module Controllers
      class TeamServiceState
        def update_push_state(team, service, status, message)
          ::Themis::Finals::Models::DB.transaction do
            service_state = get_service_state(status)

            ::Themis::Finals::Models::TeamServicePushHistoryState.create(
              state: service_state,
              message: message,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::Themis::Finals::Models::TeamServicePushState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::Themis::Finals::Models::TeamServicePushState.create(
                  state: service_state,
                  message: message,
                  created_at: ::DateTime.now,
                  updated_at: ::DateTime.now,
                  team_id: team.id,
                  service_id: service.id
                )
            else
              team_service_state.state = service_state
              team_service_state.message = message
              team_service_state.updated_at = ::DateTime.now
              team_service_state.save
            end

            partial_event_data = {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: nil,
              updated_at: team_service_state.updated_at.iso8601
            }

            full_event_data = {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: team_service_state.message,
              updated_at: team_service_state.updated_at.iso8601
            }

            team_data = {}

            ::Themis::Finals::Models::Team.all.each do |t|
              team_data[t.id] = (t.id == team_service_state.team_id) ? full_event_data : partial_event_data
            end

            ::Themis::Finals::Utils::EventEmitter.emit(
              'team/service/push-state',
              full_event_data,
              nil,
              partial_event_data,
              team_data
            )

            ::Themis::Finals::Utils::EventEmitter.emit_log(
              31,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: team_service_state.message
            )
          end
        end

        def update_pull_state(team, service, status, message)
          ::Themis::Finals::Models::DB.transaction do
            service_state = get_service_state(status)

            ::Themis::Finals::Models::TeamServicePullHistoryState.create(
              state: service_state,
              message: message,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::Themis::Finals::Models::TeamServicePullState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::Themis::Finals::Models::TeamServicePullState.create(
                  state: service_state,
                  message: message,
                  created_at: ::DateTime.now,
                  updated_at: ::DateTime.now,
                  team_id: team.id,
                  service_id: service.id
                )
            else
              team_service_state.state = service_state
              team_service_state.message = message
              team_service_state.updated_at = ::DateTime.now
              team_service_state.save
            end

            partial_event_data = {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: nil,
              updated_at: team_service_state.updated_at.iso8601
            }

            full_event_data = {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: team_service_state.message,
              updated_at: team_service_state.updated_at.iso8601
            }

            team_data = {}
            ::Themis::Finals::Models::Team.all.each do |t|
              team_data[t.id] = (t.id == team_service_state.team_id) ? full_event_data : partial_event_data
            end

            ::Themis::Finals::Utils::EventEmitter.emit(
              'team/service/pull-state',
              full_event_data,
              nil,
              partial_event_data,
              team_data
            )

            ::Themis::Finals::Utils::EventEmitter.emit_log(
              32,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: team_service_state.message
            )
          end
        end

        private
        def get_service_state(status)
          case status
          when ::Themis::Finals::Checker::Result::UP
            ::Themis::Finals::Constants::TeamServiceState::UP
          when ::Themis::Finals::Checker::Result::CORRUPT
            ::Themis::Finals::Constants::TeamServiceState::CORRUPT
          when ::Themis::Finals::Checker::Result::MUMBLE
            ::Themis::Finals::Constants::TeamServiceState::MUMBLE
          when ::Themis::Finals::Checker::Result::DOWN
            ::Themis::Finals::Constants::TeamServiceState::DOWN
          when ::Themis::Finals::Checker::Result::INTERNAL_ERROR
            ::Themis::Finals::Constants::TeamServiceState::INTERNAL_ERROR
          else
            ::Themis::Finals::Constants::TeamServiceState::NOT_AVAILABLE
          end
        end
      end
    end
  end
end
