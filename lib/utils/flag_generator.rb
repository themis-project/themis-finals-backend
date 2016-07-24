require 'securerandom'
require 'digest/md5'

module Themis
  module Finals
    module Utils
      module FlagGenerator
        def self.get_flag
          source = ::Digest::MD5.new
          source << ::SecureRandom.random_bytes(32)
          source << ::Themis::Finals::Configuration.get_contest_flow.generator_secret
          flag = "#{source.hexdigest}="
          adjunct = ::SecureRandom.random_bytes 10
          return flag, adjunct
        end
      end
    end
  end
end
