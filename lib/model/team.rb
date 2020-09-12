require 'sequel'

module VolgaCTF
  module Final
    module Model
      class Team < ::Sequel::Model
        one_to_many :team_service_states
        one_to_many :scores
        one_to_many :attack_attempts
        one_to_many :attacks
        one_to_one :total_score

        def serialize
          {
            id: id,
            name: name,
            guest: guest,
            logo_hash: logo_hash
          }
        end

        dataset_module do
          def ordered
            order(:id)
          end
        end
      end
    end
  end
end
