require 'sinatra/base'
require 'sinatra/json'

require './lib/model/bootstrap'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/service/v1/list' do
          json ::VolgaCTF::Final::Model::Service.enabled.map { |service|
            {
              id: service.id,
              name: service.name
            }
          }
        end

        get %r{/api/service/v1/status/(\d{1,2})} do |id|
          content_type :text

          team = @identity_ctrl.get_team(@remote_ip)
          if team.nil?
            halt 403
          end

          id = id.to_i
          service = ::VolgaCTF::Final::Model::Service[id]
          halt 404 if service.nil? || !service.enabled

          stage = @competition_stage_ctrl.current
          r = if @team_service_state_ctrl.up?(stage, team, service)
            ::VolgaCTF::Final::Const::ServiceStatus::UP
          else
            ::VolgaCTF::Final::Const::ServiceStatus::NOT_UP
          end
          ::VolgaCTF::Final::Const::ServiceStatus.key(r).to_s
        end
      end
    end
  end
end
