require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'ip'
require 'date'
require 'bigdecimal'
require './lib/controllers/identity'
require 'themis/finals/attack/result'
require './lib/controllers/attack'
require './lib/controllers/contest'
require './lib/utils/event_emitter'
require './lib/controllers/scoreboard_state'
require './lib/controllers/token'
require './lib/server/rack_monkey_patch'
require './lib/models/init'

module Themis
  module Finals
    module Server
      class Application < ::Sinatra::Base
        configure do
          ::Themis::Finals::Models.init
        end

        configure :production, :development do
          enable :logging
        end

        disable :run

        get '/identity' do
          remote_ip = ::IP.new request.ip
          identity = nil

          identity_team = \
            ::Themis::Finals::Controllers::IdentityController.is_team remote_ip
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? &&
             ::Themis::Finals::Controllers::IdentityController.is_internal(
               remote_ip
             )
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json identity
        end

        get '/contest/round' do
          round = ::Themis::Finals::Models::Round.count
          json(value: (round == 0) ? nil : round)
        end

        get '/contest/state' do
          state = ::Themis::Finals::Models::ContestState.last
          json(value: state.nil? ? nil : state.state)
        end

        get '/scoreboard' do
          remote_ip = ::IP.new request.ip
          is_internal = \
            ::Themis::Finals::Controllers::IdentityController.is_internal(
              remote_ip
            )

          muted = \
            if is_internal
              false
            else
              !::Themis::Finals::Controllers::ScoreboardState.is_enabled
            end

          positions = ::Themis::Finals::Controllers::Contest.get_team_positions

          json(
            muted: muted,
            positions: \
              ::Themis::Finals::Controllers::Contest.format_team_positions(
                positions
              )
          )
        end

        get '/teams' do
          json ::Themis::Finals::Models::Team.map { |team|
            {
              id: team.id,
              name: team.name,
              guest: team.guest
            }
          }
        end

        get '/services' do
          json ::Themis::Finals::Models::Service.map { |service|
            {
              id: service.id,
              name: service.name
            }
          }
        end

        get '/posts' do
          json ::Themis::Finals::Models::Post.map { |post|
            {
              id: post.id,
              title: post.title,
              description: post.description,
              created_at: post.created_at.iso8601,
              updated_at: post.updated_at.iso8601
            }
          }
        end

        post '/post' do
          unless request.content_type == 'application/json'
            halt 400
          end

          remote_ip = ::IP.new request.ip

          unless ::Themis::Finals::Controllers::IdentityController.is_internal(
            remote_ip
          )
            halt 400
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse request.body.read
          rescue => e
            halt 400
          end

          unless payload.key?('title') && payload.key?('description')
            halt 400
          end

          begin
            ::Themis::Finals::Models::DB.transaction do
              post = ::Themis::Finals::Models::Post.create(
                title: payload['title'],
                description: payload['description'],
                created_at: ::DateTime.now,
                updated_at: ::DateTime.now
              )

              ::Themis::Finals::Utils::EventEmitter.emit_all(
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

        delete %r{^/post/(\d+)$} do |post_id_str|
          remote_ip = ::IP.new request.ip

          unless ::Themis::Finals::Controllers::IdentityController.is_internal(
            remote_ip
          )
            halt 400
          end

          post_id = post_id_str.to_i
          post = ::Themis::Finals::Models::Post[post_id]
          halt 404 if post.nil?

          ::Themis::Finals::Models::DB.transaction do
            post.destroy

            ::Themis::Finals::Utils::EventEmitter.emit_all(
              'posts/remove',
              id: post_id
            )
          end

          status 204
          body ''
        end

        put %r{^/post/(\d+)$} do |post_id_str|
          unless request.content_type == 'application/json'
            halt 400
          end

          remote_ip = ::IP.new request.ip

          unless ::Themis::Finals::Controllers::IdentityController.is_internal(
            remote_ip
          )
            halt 400
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse request.body.read
          rescue => e
            halt 400
          end

          unless payload.key?('title') && payload.key?('description')
            halt 400
          end

          post_id = post_id_str.to_i
          post = ::Themis::Finals::Models::Post[post_id]
          halt 404 if post.nil?

          begin
            ::Themis::Finals::Models::DB.transaction do
              post.title = payload['title']
              post.description = payload['description']
              post.updated_at = ::DateTime.now
              post.save

              ::Themis::Finals::Utils::EventEmitter.emit_all(
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

        # get '/team/scores' do
        #   scoreboard_state = ::Themis::Finals::Models::ScoreboardState.last
        #   scoreboard_enabled = scoreboard_state.nil? ? true : scoreboard_state.enabled

        #   remote_ip = ::IP.new request.ip

        #   if scoreboard_enabled ||
        #      ::Themis::Finals::Controllers::IdentityController.is_internal(
        #        remote_ip
        #      )
        #     r = ::Themis::Finals::Models::TotalScore.map do |total_score|
        #       {
        #         id: total_score.id,
        #         team_id: total_score.team_id,
        #         defence_points: total_score.defence_points.to_f.round(4),
        #         attack_points: total_score.attack_points.to_f.round(4)
        #       }
        #     end
        #   else
        #     r = scoreboard_state.total_scores
        #   end

        #   json r
        # end

        get '/team/services' do
          json ::Themis::Finals::Models::TeamServiceState.map { |team_service_state|
            {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              updated_at: team_service_state.updated_at.iso8601
            }
          }
        end

        # get '/team/attacks' do
        #   scoreboard_state = ::Themis::Finals::Models::ScoreboardState.last
        #   scoreboard_enabled = scoreboard_state.nil? ? true : scoreboard_state.enabled

        #   remote_ip = ::IP.new request.ip

        #   if scoreboard_enabled ||
        #      ::Themis::Finals::Controllers::IdentityController.is_internal(
        #        remote_ip
        #      )
        #     r = ::Themis::Finals::Controllers::Attack.get_recent.map do |attack|
        #       {
        #         id: attack.id,
        #         occured_at: attack.occured_at.iso8601,
        #         team_id: attack.team_id
        #       }
        #     end
        #   else
        #     r = scoreboard_state.attacks
        #   end

        #   json r
        # end

        get %r{^/team/pictures/(\d{1,2})$} do |team_id_str|
          team_id = team_id_str.to_i
          team = ::Themis::Finals::Models::Team[team_id]
          halt 404 if team.nil?

          filename = ::File.join ENV['TEAM_LOGOS_DIR'], "#{team.alias}.png"
          unless ::File.exist? filename
            filename = ::File.join ::Dir.pwd, 'pictures', '__default.png'
          end

          send_file filename
        end

        post '/submit' do
          unless request.content_type == 'application/json'
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          remote_ip = ::IP.new request.ip

          team = ::Themis::Finals::Controllers::IdentityController.is_team(
            remote_ip
          )
          if team.nil?
            halt 400, json(
              ::Themis::Finals::Attack::Result::ERR_INVALID_IDENTITY
            )
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse request.body.read
          rescue => e
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          unless payload.respond_to? 'map'
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          state = ::Themis::Finals::Models::ContestState.last
          if state.nil? || state.is_initial || state.is_await_start
            halt 400, json(
              ::Themis::Finals::Attack::Result::ERR_CONTEST_NOT_STARTED
            )
          end

          if state.is_paused
            halt 400, json(::Themis::Finals::Attack::Result::ERR_CONTEST_PAUSED)
          end

          if state.is_completed
            halt 400, json(
              ::Themis::Finals::Attack::Result::ERR_CONTEST_COMPLETED
            )
          end

          r = payload.map do |flag|
            ::Themis::Finals::Controllers::Attack.process team, flag
          end

          if r.count == 0
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          json r
        end

        post '/checker/v1/report_push' do
          unless request.content_type == 'application/json'
            halt 400
          end

          header_name = "HTTP_#{ENV['THEMIS_FINALS_AUTH_TOKEN_HEADER'].upcase.gsub('-', '_')}"
          auth_token = request.env[header_name]

          halt 401 unless ::Themis::Finals::Controllers::Token.verify_checker_token(auth_token)

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse request.body.read
          rescue => e
            halt 400
          end

          begin
            flag = ::Themis::Finals::Models::Flag.first(
              flag: payload['flag']
            )
            if flag.nil?
              halt 400
            else
              ::Themis::Finals::Controllers::Contest.handle_push(
                flag,
                payload['status'],
                ::Base64.urlsafe_decode64(payload['adjunct'])
              )
            end
          rescue => e
            halt 400
          end

          status 200
          body ''
        end

        post '/checker/v1/report_pull' do
          unless request.content_type == 'application/json'
            halt 400
          end

          header_name = "HTTP_#{ENV['THEMIS_FINALS_AUTH_TOKEN_HEADER'].upcase.gsub('-', '_')}"
          auth_token = request.env[header_name]

          halt 401 unless ::Themis::Finals::Controllers::Token.verify_checker_token(auth_token)

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse request.body.read
          rescue => e
            halt 400
          end

          begin
            poll = ::Themis::Finals::Models::FlagPoll.first(
              id: payload['request_id']
            )
            if poll.nil?
              halt 400
            else
              ::Themis::Finals::Controllers::Contest.handle_poll(
                poll,
                payload['status']
              )
            end
          rescue => e
            halt 400
          end

          status 200
          body ''
        end
      end
    end
  end
end
