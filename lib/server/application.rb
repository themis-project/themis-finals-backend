require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'ip'
require 'date'
require 'tempfile'
require 'mini_magick'

require './lib/controllers/attack'
require './lib/utils/event_emitter'
require './lib/utils/tempfile_monkey_patch'
require './lib/server/rack_monkey_patch'
require './lib/models/bootstrap'
require './lib/controllers/ctftime'
require './lib/constants/submit_result'
require './lib/constants/service_status'

require './lib/controllers/identity'
require './lib/controllers/competition'
require './lib/controllers/competition_stage'
require './lib/controllers/scoreboard'
require './lib/controllers/image'
require './lib/controllers/score'
require './lib/controllers/team_service_state'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        def initialize(app = nil)
          super(app)

          @identity_ctrl = ::VolgaCTF::Final::Controllers::Identity.new
          @ctftime_ctrl = ::VolgaCTF::Final::Controllers::CTFTime.new
          @competition_stage_ctrl = ::VolgaCTF::Final::Controllers::CompetitionStage.new
          @competition_ctrl = ::VolgaCTF::Final::Controllers::Competition.new
          @attack_ctrl = ::VolgaCTF::Final::Controllers::Attack.new
          @scoreboard_ctrl = ::VolgaCTF::Final::Controllers::Scoreboard.new
          @image_ctrl = ::VolgaCTF::Final::Controllers::Image.new
          @score_ctrl = ::VolgaCTF::Final::Controllers::Score.new
          @team_service_state_ctrl = ::VolgaCTF::Final::Controllers::TeamServiceState.new

          ::MiniMagick.configure do |config|
            config.cli = :graphicsmagick
          end
        end

        configure do
          ::VolgaCTF::Final::Models.init
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

          identity_team = @identity_ctrl.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_ctrl.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json identity
        end

        get '/api/competition/round' do
          round = ::VolgaCTF::Final::Models::Round.count
          json(value: (round == 0) ? nil : round)
        end

        get '/api/competition/stage' do
          json(value: @competition_stage_ctrl.current.stage)
        end

        get '/api/scoreboard' do
          muted = \
            if @identity_ctrl.is_internal?(@remote_ip)
              false
            else
              !@scoreboard_ctrl.broadcast?
            end

          if muted
            obj = ::VolgaCTF::Final::Models::ScoreboardHistoryPosition.last
          else
            obj = ::VolgaCTF::Final::Models::ScoreboardPosition.last
          end

          json(
            muted: muted,
            positions: obj.nil? ? {} : obj.data
          )
        end

        get '/api/third-party/ctftime' do
          muted = \
            if @identity_ctrl.is_internal?(@remote_ip)
              false
            else
              !@scoreboard_ctrl.broadcast?
            end

          if muted
            obj = ::VolgaCTF::Final::Models::ScoreboardHistoryPosition.last
          else
            obj = ::VolgaCTF::Final::Models::ScoreboardPosition.last
          end

          json(
            standings: obj.nil? ? [] : @ctftime_ctrl.format_positions(obj.data)
          )
        end

        get '/api/teams' do
          json ::VolgaCTF::Final::Models::Team.map { |t| t.serialize }
        end

        get '/api/services' do
          json ::VolgaCTF::Final::Models::Service.enabled.map { |s| s.serialize }
        end

        get '/api/posts' do
          json ::VolgaCTF::Final::Models::Post.map { |post|
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
            ::VolgaCTF::Final::Models::DB.transaction do
              post = ::VolgaCTF::Final::Models::Post.create(
                title: payload['title'],
                description: payload['description'],
                created_at: ::DateTime.now,
                updated_at: ::DateTime.now
              )

              ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
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
          post = ::VolgaCTF::Final::Models::Post[post_id]
          halt 404 if post.nil?

          ::VolgaCTF::Final::Models::DB.transaction do
            post.destroy

            ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
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
          post = ::VolgaCTF::Final::Models::Post[post_id]
          halt 404 if post.nil?

          begin
            ::VolgaCTF::Final::Models::DB.transaction do
              post.title = payload['title']
              post.description = payload['description']
              post.updated_at = ::DateTime.now
              post.save

              ::VolgaCTF::Final::Utils::EventEmitter.broadcast(
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

        post '/api/team/logo' do
          team = @identity_ctrl.get_team(@remote_ip)

          if team.nil?
            halt 401, 'Unauthorized'
          end

          unless params[:file]
            halt 400, 'No file'
          end

          path = nil
          upload = params[:file][:tempfile]
          extension = ::File.extname(params[:file][:filename])
          t = Tempfile.open(['logo', extension], ::ENV['VOLGACTF_FINAL_UPLOAD_DIR']) do |f|
            f.write(upload.read)
            path = f.path
            f.persist  # introduced by a monkey patch
          end

          image = @image_ctrl.load(path)
          if image.nil?
            halt 400, 'Error processing image'
          end

          if image.width != image.height
            halt 400, 'Image width must equal its height'
          end

          @image_ctrl.perform_resize(path, team.id)
          status 201
          body 'OK'
        end

        get %r{^/api/team/(\d{1,2})/stats$} do |team_id_str|
          unless @identity_ctrl.is_internal?(@remote_ip)
            halt 401
          end

          team_id = team_id_str.to_i
          team = ::VolgaCTF::Final::Models::Team[team_id]
          halt 404 if team.nil?

          json @score_ctrl.get_team_scores(team).map { |s| s.serialize }
        end

        get '/api/team/stats' do
          team = @identity_ctrl.get_team(@remote_ip)

          if team.nil?
            halt 401, 'Unauthorized'
          end

          json @score_ctrl.get_team_scores(team).map { |s| s.serialize }
        end

        get '/api/team/service/push-states' do
          identity = nil

          identity_team = @identity_ctrl.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_ctrl.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json ::VolgaCTF::Final::Models::TeamServicePushState.map { |team_service_state|
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

          identity_team = @identity_ctrl.get_team(@remote_ip)
          unless identity_team.nil?
            identity = { name: 'team', id: identity_team.id }
          end

          if identity.nil? && @identity_ctrl.is_internal?(@remote_ip)
            identity = { name: 'internal' }
          end

          if identity.nil?
            identity = { name: 'external' }
          end

          json ::VolgaCTF::Final::Models::TeamServicePullState.map { |team_service_state|
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

        get %r{^/api/team/logo/(\d{1,2})\.png$} do |team_id_str|
          team_id = team_id_str.to_i
          team = ::VolgaCTF::Final::Models::Team[team_id]
          halt 404 if team.nil?

          filename = ::File.join(::ENV['VOLGACTF_FINAL_TEAM_LOGO_DIR'], "#{team.alias}.png")
          unless ::File.exist?(filename)
            filename = ::File.join(::Dir.pwd, 'logo', 'default.png')
          end

          send_file filename
        end

        get '/api/service/v1/list' do
          json ::VolgaCTF::Final::Models::Service.enabled.map { |service|
            {
              id: service.id,
              name: service.name
            }
          }
        end

        get %r{^/api/service/v1/status/(\d{1,2})$} do |service_id_str|
          content_type :text

          team = @identity_ctrl.get_team(@remote_ip)
          if team.nil?
            halt 403
          end

          service_id = service_id_str.to_i
          service = ::VolgaCTF::Final::Models::Service[service_id]
          halt 404 if service.nil? || !service.enabled

          stage = @competition_stage_ctrl.current
          r = if @team_service_state_ctrl.up?(stage, team, service)
            ::VolgaCTF::Final::Constants::ServiceStatus::UP
          else
            ::VolgaCTF::Final::Constants::ServiceStatus::NOT_UP
          end
          ::VolgaCTF::Final::Constants::ServiceStatus.key(r).to_s
        end

        get '/api/capsule/v1/public_key' do
          content_type :text
          ::ENV.fetch('VOLGACTF_FINAL_FLAG_SIGN_KEY_PUBLIC', '').gsub('\n', "\n")
        end

        post '/api/flag/v1/submit' do
          content_type :text
          unless request.content_type == 'text/plain'
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_FLAG_INVALID).to_s
          end

          team = @identity_ctrl.get_team(@remote_ip)

          if team.nil?
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_ACCESS_DENIED).to_s
          end

          payload = nil

          begin
            request.body.rewind
            flag_str = request.body.read
          rescue => e
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_FLAG_INVALID).to_s
          end

          stage = @competition_stage_ctrl.current
          if stage.not_started? || stage.starting?
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_COMPETITION_NOT_STARTED).to_s
          end

          if stage.paused?
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_COMPETITION_PAUSED).to_s
          end

          if stage.finished?
            halt 400, ::VolgaCTF::Final::Constants::SubmitResult.key(
              ::VolgaCTF::Final::Constants::SubmitResult::ERROR_COMPETITION_FINISHED).to_s
          end

          r = @attack_ctrl.handle(stage, team, flag_str)
          ::VolgaCTF::Final::Constants::SubmitResult.key(r).to_s
        end

        get %r{^/api/flag/v1/info/([\da-f]{32}=)$} do |flag_str|
          flag_obj = ::VolgaCTF::Final::Models::Flag.exclude(
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

        post '/api/checker/v2/report_push' do
          unless request.content_type == 'application/json'
            halt 400
          end

          payload = nil

          begin
            request.body.rewind
            payload = ::JSON.parse(request.body.read)
          rescue => e
            halt 400
          end

          begin
            flag = ::VolgaCTF::Final::Models::Flag.first(
              flag: payload['flag']
            )
            if flag.nil?
              halt 400
            else
              @competition_ctrl.handle_push(
                flag,
                payload['status'],
                payload['label'],
                payload['message']
              )
            end
          rescue => e
            halt 400
          end

          status 204
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
            poll = ::VolgaCTF::Final::Models::FlagPoll.first(
              id: payload['request_id']
            )
            if poll.nil?
              halt 400
            else
              @competition_ctrl.handle_pull(
                poll,
                payload['status'],
                payload['message']
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
