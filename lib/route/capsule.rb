require 'sinatra/base'

module VolgaCTF
  module Final
    module Server
      class Application < ::Sinatra::Base
        get '/api/capsule/v1/public_key' do
          content_type :text
          ::ENV.fetch('VOLGACTF_FINAL_FLAG_SIGN_KEY_PUBLIC', '').gsub('\n', "\n")
        end
      end
    end
  end
end
