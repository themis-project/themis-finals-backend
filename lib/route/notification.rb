require 'sinatra/base'
require 'sinatra/json'
require 'json'

require './lib/model/bootstrap'
require './lib/util/event_emitter'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/posts' do
          json ::VolgaCTF::Final::Model::Post.map { |post|
            {
              id: post.id,
              title: post.title,
              description: post.description,
              created_at: post.created_at.iso8601,
              updated_at: post.updated_at.iso8601
            }
          }
        end

        post '/api/post' do
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

          begin
            ::VolgaCTF::Final::Model::DB.transaction do
              post = ::VolgaCTF::Final::Model::Post.create(
                title: payload['title'],
                description: payload['description'],
                created_at: ::DateTime.now,
                updated_at: ::DateTime.now
              )

              ::VolgaCTF::Final::Util::EventEmitter.broadcast(
                'posts/add',
                id: post.id,
                title: post.title,
                description: post.description,
                created_at: post.created_at.iso8601,
                updated_at: post.updated_at.iso8601
              )
            end
          rescue => e
            halt 400
          end

          status 201
          body ''
        end

        delete %r{^/api/post/(\d+)$} do |post_id_str|
          unless @identity_ctrl.is_internal?(@remote_ip)
            halt 400
          end

          post_id = post_id_str.to_i
          post = ::VolgaCTF::Final::Model::Post[post_id]
          halt 404 if post.nil?

          ::VolgaCTF::Final::Model::DB.transaction do
            post.destroy

            ::VolgaCTF::Final::Util::EventEmitter.broadcast(
              'posts/remove',
              id: post_id
            )
          end

          status 204
          body ''
        end

        put %r{^/api/post/(\d+)$} do |post_id_str|
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

          post_id = post_id_str.to_i
          post = ::VolgaCTF::Final::Model::Post[post_id]
          halt 404 if post.nil?

          begin
            ::VolgaCTF::Final::Model::DB.transaction do
              post.title = payload['title']
              post.description = payload['description']
              post.updated_at = ::DateTime.now
              post.save

              ::VolgaCTF::Final::Util::EventEmitter.broadcast(
                'posts/edit',
                id: post.id,
                title: post.title,
                description: post.description,
                created_at: post.created_at.iso8601,
                updated_at: post.updated_at.iso8601
              )
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
