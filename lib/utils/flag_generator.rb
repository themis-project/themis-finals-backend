require 'securerandom'
require 'digest/md5'
require 'base64'

module Themis
  module Finals
    module Utils
      module FlagGenerator
        def self.generate_flag
          source = ::Digest::MD5.new
          source << ::SecureRandom.random_bytes(32)
          source << ::Base64.urlsafe_decode64(
            ENV['THEMIS_FINALS_FLAG_GENERATOR_SECRET']
          )
          flag = "#{source.hexdigest}="
          label = ::SecureRandom.uuid
          return flag, label
        end
      end
    end
  end
end
