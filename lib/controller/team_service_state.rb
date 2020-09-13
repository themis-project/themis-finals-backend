require 'date'

require 'volgactf/final/checker/result'

require './lib/const/team_service_state'
require './lib/util/event_emitter'

module VolgaCTF
  module Final
    module Controller
      class TeamServiceState
        def up?(stage, team, service)
          if stage.any?(:not_started, :starting, :paused, :finished)
            return false
          end

          pull = ::VolgaCTF::Final::Model::TeamServicePullState.first(
            team_id: team.id,
            service_id: service.id
          )
          pull_ok = !pull.nil? && pull.state == ::VolgaCTF::Final::Const::TeamServiceState::UP

          if stage.any?(:pausing, :finishing)
            return pull_ok
          end

          push = ::VolgaCTF::Final::Model::TeamServicePushState.first(
            team_id: team.id,
            service_id: service.id
          )
          push_ok = !push.nil? && push.state == ::VolgaCTF::Final::Const::TeamServiceState::UP

          push_ok && pull_ok
        end

        def update_push_state(team, service, status, message)
          ::VolgaCTF::Final::Model::DB.transaction do
            service_state = get_service_state(status)

            ::VolgaCTF::Final::Model::TeamServicePushHistoryState.create(
              state: service_state,
              message: message,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::VolgaCTF::Final::Model::TeamServicePushState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::VolgaCTF::Final::Model::TeamServicePushState.create(
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

            ::VolgaCTF::Final::Model::Team.all.each do |t|
              team_data[t.id] = (t.id == team_service_state.team_id) ? full_event_data : partial_event_data
            end

            ::VolgaCTF::Final::Util::EventEmitter.emit(
              'team/service/push-state',
              full_event_data,
              nil,
              partial_event_data,
              team_data
            )
          end
        end

        def update_pull_state(team, service, status, message)
          ::VolgaCTF::Final::Model::DB.transaction do
            service_state = get_service_state(status)

            ::VolgaCTF::Final::Model::TeamServicePullHistoryState.create(
              state: service_state,
              message: message,
              created_at: ::DateTime.now,
              team_id: team.id,
              service_id: service.id
            )

            team_service_state = \
              ::VolgaCTF::Final::Model::TeamServicePullState.first(
                service_id: service.id,
                team_id: team.id
              )

            if team_service_state.nil?
              team_service_state = \
                ::VolgaCTF::Final::Model::TeamServicePullState.create(
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
            ::VolgaCTF::Final::Model::Team.all.each do |t|
              team_data[t.id] = (t.id == team_service_state.team_id) ? full_event_data : partial_event_data
            end

            ::VolgaCTF::Final::Util::EventEmitter.emit(
              'team/service/pull-state',
              full_event_data,
              nil,
              partial_event_data,
              team_data
            )
          end
        end

        private
        def get_service_state(status)
          case status
          when ::VolgaCTF::Final::Checker::Result::UP
            ::VolgaCTF::Final::Const::TeamServiceState::UP
          when ::VolgaCTF::Final::Checker::Result::CORRUPT
            ::VolgaCTF::Final::Const::TeamServiceState::CORRUPT
          when ::VolgaCTF::Final::Checker::Result::MUMBLE
            ::VolgaCTF::Final::Const::TeamServiceState::MUMBLE
          when ::VolgaCTF::Final::Checker::Result::DOWN
            ::VolgaCTF::Final::Const::TeamServiceState::DOWN
          when ::VolgaCTF::Final::Checker::Result::INTERNAL_ERROR
            ::VolgaCTF::Final::Const::TeamServiceState::INTERNAL_ERROR
          else
            ::VolgaCTF::Final::Const::TeamServiceState::NOT_AVAILABLE
          end
        end
      end
    end
  end
end
