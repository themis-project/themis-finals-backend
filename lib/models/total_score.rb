require 'sequel'

module VolgaCTF
  module Final
    module Models
      class TotalScore < ::Sequel::Model
        many_to_one :team
      end
    end
  end
end
