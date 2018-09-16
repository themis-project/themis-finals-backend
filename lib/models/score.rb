require 'sequel'

module Themis
  module Finals
    module Models
      class Score < ::Sequel::Model
        many_to_one :team
        many_to_one :round

        def serialize
          {
            id: id,
            attack_points: attack_points,
            availability_points: availability_points,
            defence_points: defence_points,
            team_id: team_id,
            round_id: round_id
          }
        end

        dataset_module do
          def filter_by_team_round(team, round)
            where(team_id: team.id)
            .where { round_id <= round.id }
            .order(::Sequel.desc(:round_id))
          end
        end
      end
    end
  end
end
