::Sequel.migration do
  up do
    create_table(:total_scores) do
      primary_key :id
      Float :attack_points, null: false, default: 0.0
      Float :availability_points, null: false, default: 0.0
      Float :defence_points, null: false, default: 0.0
      foreign_key :team_id, :teams, index: true, unique: true, null: false
    end
  end

  down do
    drop_table(:total_scores)
  end
end
