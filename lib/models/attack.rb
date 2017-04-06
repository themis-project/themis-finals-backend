require 'sequel'

module Themis
  module Finals
    module Models
      class Attack < ::Sequel::Model
        many_to_one :team
        many_to_one :flag
      end
    end
  end
end
