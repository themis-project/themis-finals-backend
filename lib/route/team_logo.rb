require 'sinatra/base'
require 'tempfile'

require './lib/model/bootstrap'
require './lib/util/tempfile_monkey_patch'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get %r{/api/team/logo/(\d{1,2})\.png} do |team_id_str|
          team_id = team_id_str.to_i
          team = ::VolgaCTF::Final::Model::Team[team_id]
          halt 404 if team.nil?

          filename = ::File.join(::ENV['VOLGACTF_FINAL_TEAM_LOGO_DIR'], "#{team.alias}.png")
          unless ::File.exist?(filename)
            filename = ::File.join(::Dir.pwd, 'logo', 'default.png')
          end

          cache_control :public
          send_file filename
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
          headers 'Location' => "/api/team/logo/#{team.id}.png"
          body ''
        end
      end
    end
  end
end
