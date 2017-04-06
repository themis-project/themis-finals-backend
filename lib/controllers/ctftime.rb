module Themis
  module Finals
    module Controllers
      module CTFTime
        @logger = ::Themis::Finals::Utils::Logger.get

        def self.format_positions(positions)
          teams = {}
          ::Themis::Finals::Models::Team.all.each do |team|
            teams[team.id] = team.name
          end

          positions.each_with_index.map do |position, ndx|
            {
              pos: ndx + 1,
              team: teams[position['team_id']],
              score: position['total_relative']
            }
          end
        end
      end
    end
  end
end
