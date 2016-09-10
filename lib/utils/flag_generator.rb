require 'securerandom'
require 'digest/md5'
require 'base64'

module Themis
  module Finals
    module Utils
      module FlagGenerator
        def self.get_flag
          source = ::Digest::MD5.new
          source << ::SecureRandom.random_bytes(32)
          source << ::Base64.urlsafe_decode64(
            ENV['THEMIS_FINALS_FLAG_GENERATOR_SECRET']
          )
          flag = "#{source.hexdigest}="
          adjunct = ::SecureRandom.random_bytes(10)
          return flag, adjunct
        end
      end
    end
  end
end
