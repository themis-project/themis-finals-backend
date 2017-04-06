require 'sequel'

module Themis
  module Finals
    module Models
      class AttackAttempt < ::Sequel::Model
        many_to_one :team
      end
    end
  end
end
