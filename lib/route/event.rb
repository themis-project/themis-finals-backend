require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'date'

require './lib/model/bootstrap'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/event/history' do
          halt 403 unless @identity_ctrl.is_internal?(@remote_ip)

          unless params.key?('timestamp') && params.key?('page') && params.key?('page_size')
            halt 400
          end

          timestamp = ::Time.at(params['timestamp'].to_i).utc.to_datetime
          page = params['page'].to_i
          page_size = params['page_size'].to_i

          total = ::VolgaCTF::Final::Model::ServerSentEvent.log_before(timestamp).count
          entries = ::VolgaCTF::Final::Model::ServerSentEvent.paginate(timestamp, page, page_size)
          json(
            timestamp: timestamp,
            page: page,
            page_size: page_size,
            total: total,
            entries: entries.map { |e| e.serialize_log }
          )
        end
      end
    end
  end
end
