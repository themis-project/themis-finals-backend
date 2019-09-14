require 'sinatra/base'
require 'sinatra/json'
require 'json'

require './lib/model/bootstrap'
require './lib/util/event_emitter'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/notifications' do
          identity_team = @identity_ctrl.get_team(@remote_ip)
          if identity_team.nil?
            if @identity_ctrl.is_internal?(@remote_ip)
              q = ::VolgaCTF::Final::Model::Notification.for_admin
            else
              q = ::VolgaCTF::Final::Model::Notification.for_guest
            end
          else
            q = ::VolgaCTF::Final::Model::Notification.for_team(identity_team)
          end

          json(q.map { |n| n.serialize })
        end

        post '/api/notification' do
          unless request.content_type == 'application/json'
            halt 400
          end

          unless @identity_ctrl.is_internal?(@remote_ip)
            halt 400
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse(request.body.read)
          rescue => e
            halt 400
          end

          recipient_id = nil
          if payload.key?('team_id') && !payload['team_id'].nil?
            team = ::VolgaCTF::Final::Model::Team[payload['team_id']]
            halt 400 if team.nil?
            recipient_id = team.id
          end

          unless payload.key?('title') && payload.key?('description')
            halt 400
          end

          begin
            ::VolgaCTF::Final::Model::DB.transaction do
              notification = ::VolgaCTF::Final::Model::Notification.create(
                title: payload['title'],
                description: payload['description'],
                team_id: recipient_id,
                created_at: ::DateTime.now,
                updated_at: ::DateTime.now
              )

              event_data = notification.serialize
              if recipient_id.nil?
                ::VolgaCTF::Final::Util::EventEmitter.broadcast(
                  'notification/add',
                  event_data
                )
              else
                ::VolgaCTF::Final::Util::EventEmitter.emit(
                  'notification/add',
                  event_data,
                  nil,
                  nil,
                  ::Hash[recipient_id, event_data]
                )
              end
            end
          rescue => e
            halt 400
          end

          status 201
          headers 'Location' => '/api/notifications'
          body ''
        end

        delete %r{/api/notification/(\d+)} do |id|
          unless @identity_ctrl.is_internal?(@remote_ip)
            halt 400
          end

          id = id.to_i
          notification = ::VolgaCTF::Final::Model::Notification[id]
          halt 404 if notification.nil?
          recipient_id = notification.team_id

          ::VolgaCTF::Final::Model::DB.transaction do
            notification.destroy

            event_data = { id: id }
            if recipient_id.nil?
              ::VolgaCTF::Final::Util::EventEmitter.broadcast(
                'notification/remove',
                event_data
              )
            else
              ::VolgaCTF::Final::Util::EventEmitter.emit(
                'notification/remove',
                event_data,
                nil,
                nil,
                ::Hash[recipient_id, event_data]
              )
            end
          end

          status 204
          body ''
        end

        patch %r{/api/notification/(\d+)} do |id|
          unless request.content_type == 'application/json'
            halt 400
          end

          unless @identity_ctrl.is_internal?(@remote_ip)
            halt 400
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse(request.body.read)
          rescue => e
            halt 400
          end

          unless payload.key?('title') && payload.key?('description')
            halt 400
          end

          id = id.to_i
          notification = ::VolgaCTF::Final::Model::Notification[id]
          halt 404 if notification.nil?
          recipient_id = notification.team_id

          begin
            ::VolgaCTF::Final::Model::DB.transaction do
              notification.title = payload['title']
              notification.description = payload['description']
              notification.updated_at = ::DateTime.now
              notification.save

              event_data = notification.serialize
              if recipient_id.nil?
                ::VolgaCTF::Final::Util::EventEmitter.broadcast(
                  'notification/alter',
                  event_data
                )
              else
                ::VolgaCTF::Final::Util::EventEmitter.emit(
                  'notification/alter',
                  event_data,
                  nil,
                  nil,
                  ::Hash[recipient_id, event_data]
                )
              end
            end
          rescue => e
            halt 400
          end

          status 204
          body ''
        end
      end
    end
  end
end
