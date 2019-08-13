require 'sequel'

module VolgaCTF
  module Final
    module Model
      class TotalScore < ::Sequel::Model
        many_to_one :team
      end
    end
  end
end
