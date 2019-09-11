require 'sinatra/base'
require 'sinatra/json'

require './lib/model/bootstrap'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/third-party/ctftime' do
          muted = \
            if @identity_ctrl.is_internal?(@remote_ip)
              false
            else
              !@scoreboard_ctrl.broadcast?
            end

          if muted
            obj = ::VolgaCTF::Final::Model::ScoreboardHistoryPosition.last
          else
            obj = ::VolgaCTF::Final::Model::ScoreboardPosition.last
          end

          json(
            standings: obj.nil? ? [] : @ctftime_ctrl.format_positions(obj.data)
          )
        end
      end
    end
  end
end
