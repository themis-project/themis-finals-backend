require 'sequel'

module VolgaCTF
  module Final
    module Model
      class Notification < ::Sequel::Model
        def serialize
          {
            id: id,
            title: title,
            description: description,
            team_id: team_id,
            created_at: created_at.iso8601,
            updated_at: updated_at.iso8601
          }
        end

        dataset_module do
          def for_admin
            self
          end

          def for_team(team)
            where(team_id: nil).or(team_id: team.id)
          end

          def for_guest
            where(team_id: nil)
          end
        end
      end
    end
  end
end
