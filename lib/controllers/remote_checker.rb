require 'uri'
require 'net/http'

module Themis
  module Finals
    module Controllers
      class RemoteChecker
        def push(endpoint, data)
          uri = URI("#{endpoint}/push")
          make_request(uri, data)
        end

        def pull(endpoint, data)
          uri = URI("#{endpoint}/pull")
          make_request(uri, data)
        end

        private
        def make_request(uri, data)
          req = ::Net::HTTP::Post.new(uri)
          req.body = data
          req.content_type = 'application/json'
          req.basic_auth(
            ::ENV['THEMIS_FINALS_AUTH_CHECKER_USERNAME'],
            ::ENV['THEMIS_FINALS_AUTH_CHECKER_PASSWORD']
          )

          res = ::Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(req)
          end

          res.code
        end
      end
    end
  end
end
