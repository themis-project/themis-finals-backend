module Themis
  module Finals
    module Controllers
      class CTFTime
        def format_positions(positions)
          teams = {}
          ::Themis::Finals::Models::Team.all.each do |team|
            teams[team.id] = team.name
          end

          positions.each_with_index.map do |position, ndx|
            {
              pos: ndx + 1,
              team: teams[position['team_id']],
              score: position['total_points']
            }
          end
        end
      end
    end
  end
end
