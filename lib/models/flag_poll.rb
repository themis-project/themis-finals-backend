require 'sequel'

module Themis
  module Finals
    module Models
      class FlagPoll < ::Sequel::Model
        many_to_one :flag
      end
    end
  end
end
