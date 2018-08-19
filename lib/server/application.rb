require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'ip'
require 'date'
require 'themis/finals/attack/result'
require './lib/controllers/attack'
require './lib/controllers/contest'
require './lib/utils/event_emitter'
require './lib/controllers/scoreboard_state'
require './lib/server/rack_monkey_patch'
require './lib/models/init'
require './lib/controllers/scoreboard'
require './lib/controllers/ctftime'
require './lib/constants/submit_result'

require './lib/controllers/identity'

module Themis
  module Finals
    module Server
      class Application < ::Sinatra::Base
        def initialize(app = nil)
          super(app)

          @identity_controller = ::Themis::Finals::Controllers::Identity.new
          @ctftime_controller = ::Themis::Finals::Controllers::CTFTime.new
        end

        configure do
          ::Themis::Finals::Models.init
        end

        configure :production, :development do
          enable :logging
        end

        disable :run

        before do
          @remote_ip = ::IP.new(request.ip)
        end

        get '/api/identity' do
          identity = nil

          identity_team = @identity_controller.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_controller.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json identity
        end

        get '/api/contest/round' do
          round = ::Themis::Finals::Models::Round.count
          json(value: (round == 0) ? nil : round)
        end

        get '/api/contest/state' do
          state = ::Themis::Finals::Models::ContestState.last
          json(value: state.nil? ? nil : state.state)
        end

        get '/api/scoreboard' do
          muted = \
            if @identity_controller.is_internal?(@remote_ip)
              false
            else
              !::Themis::Finals::Controllers::ScoreboardState.is_enabled
            end

          if muted
            obj = ::Themis::Finals::Models::ScoreboardHistoryPosition.last
          else
            obj = ::Themis::Finals::Models::ScoreboardPosition.last
          end

          json(
            muted: muted,
            positions: obj.nil? ? {} : obj.data
          )
        end

        get '/api/third-party/ctftime' do
          muted = \
            if @identity_controller.is_internal?(@remote_ip)
              false
            else
              !::Themis::Finals::Controllers::ScoreboardState.is_enabled
            end

          if muted
            obj = ::Themis::Finals::Models::ScoreboardHistoryPosition.last
          else
            obj = ::Themis::Finals::Models::ScoreboardPosition.last
          end

          json(
            standings: obj.nil? ? [] : @ctftime_controller.format_positions(obj.data)
          )
        end

        get '/api/teams' do
          json ::Themis::Finals::Models::Team.map { |team|
            {
              id: team.id,
              name: team.name,
              guest: team.guest
            }
          }
        end

        get '/api/services' do
          json ::Themis::Finals::Models::Service.map { |service|
            {
              id: service.id,
              name: service.name
            }
          }
        end

        get '/api/posts' do
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

        post '/api/post' do
          unless request.content_type == 'application/json'
            halt 400
          end

          unless @identity_controller.is_internal?(@remote_ip)
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
            ::Themis::Finals::Models::DB.transaction do
              post = ::Themis::Finals::Models::Post.create(
                title: payload['title'],
                description: payload['description'],
                created_at: ::DateTime.now,
                updated_at: ::DateTime.now
              )

              ::Themis::Finals::Utils::EventEmitter.broadcast(
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
          unless @identity_controller.is_internal?(@remote_ip)
            halt 400
          end

          post_id = post_id_str.to_i
          post = ::Themis::Finals::Models::Post[post_id]
          halt 404 if post.nil?

          ::Themis::Finals::Models::DB.transaction do
            post.destroy

            ::Themis::Finals::Utils::EventEmitter.broadcast(
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

          unless @identity_controller.is_internal?(@remote_ip)
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
          post = ::Themis::Finals::Models::Post[post_id]
          halt 404 if post.nil?

          begin
            ::Themis::Finals::Models::DB.transaction do
              post.title = payload['title']
              post.description = payload['description']
              post.updated_at = ::DateTime.now
              post.save

              ::Themis::Finals::Utils::EventEmitter.broadcast(
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

        get '/api/team/service/push-states' do
          identity = nil

          identity_team = @identity_controller.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_controller.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json ::Themis::Finals::Models::TeamServicePushState.map { |team_service_state|
            {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: (identity[:name] == 'internal' || (identity[:name] == 'team' && identity[:id] == team_service_state.team_id)) ? team_service_state.message : nil,
              updated_at: team_service_state.updated_at.iso8601
            }
          }
        end

        get '/api/team/service/pull-states' do
          identity = nil

          identity_team = @identity_controller.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_controller.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json ::Themis::Finals::Models::TeamServicePullState.map { |team_service_state|
            {
              id: team_service_state.id,
              team_id: team_service_state.team_id,
              service_id: team_service_state.service_id,
              state: team_service_state.state,
              message: (identity[:name] == 'internal' || (identity[:name] == 'team' && identity[:id] == team_service_state.team_id)) ? team_service_state.message : nil,
              updated_at: team_service_state.updated_at.iso8601
            }
          }
        end

        get %r{^/api/team/pictures/(\d{1,2})$} do |team_id_str|
          team_id = team_id_str.to_i
          team = ::Themis::Finals::Models::Team[team_id]
          halt 404 if team.nil?

          filename = ::File.join ENV['THEMIS_FINALS_TEAM_LOGO_DIR'], "#{team.alias}.png"
          unless ::File.exist? filename
            filename = ::File.join ::Dir.pwd, 'pictures', '__default.png'
          end

          send_file filename
        end

        get '/api/capsule/v1/public_key' do
          content_type :text
          ::ENV.fetch('THEMIS_FINALS_FLAG_SIGN_KEY_PUBLIC', '').gsub('\n', "\n")
        end

        post '/api/flag/v1/submit' do
          content_type :text
          unless request.content_type == 'text/plain'
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID).to_s
          end

          team = @identity_controller.get_team(@remote_ip)

          if team.nil?
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_ACCESS_DENIED).to_s
          end

          payload = nil

          begin
            request.body.rewind
            flag_str = request.body.read
          rescue => e
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_FLAG_INVALID).to_s
          end

          state = ::Themis::Finals::Models::ContestState.last
          if state.nil? || state.is_initial || state.is_await_start
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_COMPETITION_NOT_STARTED).to_s
          end

          if state.is_paused
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_COMPETITION_PAUSED).to_s
          end

          if state.is_completed
            halt 400, ::Themis::Finals::Constants::SubmitResult.key(
              ::Themis::Finals::Constants::SubmitResult::ERROR_COMPETITION_FINISHED).to_s
          end

          r = ::Themis::Finals::Controllers::Attack.process(team, flag_str)
          ::Themis::Finals::Constants::SubmitResult.key(r).to_s
        end

        get %r{^/api/flag/v1/info/([\da-f]{32}=)$} do |flag_str|
          flag_obj = ::Themis::Finals::Models::Flag.exclude(
            pushed_at: nil
          ).where(
            flag: flag_str
          ).first

          halt 404 if flag_obj.nil?

          r = {
            flag: flag_obj.flag,
            nbf: flag_obj.pushed_at.iso8601,
            exp: flag_obj.expired_at.iso8601,
            round: flag_obj.round_id,
            team: flag_obj.team.name,
            service: flag_obj.service.name
          }

          json r
        end

        post '/api/submit' do
          unless request.content_type == 'application/json'
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          team = @identity_controller.get_team(@remote_ip)

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
            ::Themis::Finals::Controllers::Attack.process_deprecated(team, flag)
          end

          if r.count == 0
            halt 400, json(::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT)
          end

          json r
        end

        post '/api/checker/v2/report_push' do
          unless request.content_type == 'application/json'
            halt 400
          end

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
                payload['label'],
                payload['message']
              )
            end
          rescue => e
            halt 400
          end

          status 200
          body ''
        end

        post '/api/checker/v2/report_pull' do
          unless request.content_type == 'application/json'
            halt 400
          end

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
                payload['status'],
                payload['message']
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
