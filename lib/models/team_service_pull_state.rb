require 'sequel'

module VolgaCTF
  module Final
    module Models
      class TeamServicePullState < ::Sequel::Model
        many_to_one :service
        many_to_one :team
      end
    end
  end
end
