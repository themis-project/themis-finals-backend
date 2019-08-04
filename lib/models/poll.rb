require 'sequel'

module VolgaCTF
  module Final
    module Models
      class Poll < ::Sequel::Model
        many_to_one :round

        dataset_module do
          def last_relevant(round)
            where(round_id: round.id).order(::Sequel.desc(:created_at)).first
          end
        end
      end
    end
  end
end
