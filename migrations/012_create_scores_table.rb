::Sequel.migration do
  up do
    create_table(:scores) do
      primary_key :id
      Float :attack_points, null: false, default: 0.0
      Float :availability_points, null: false, default: 0.0
      Float :defence_points, null: false, default: 0.0
      foreign_key :team_id, :teams, index: true, null: false
      foreign_key :round_id, :rounds, index: true, null: false
      unique [:team_id, :round_id], name: :score_team_round_uniq
    end
  end

  down do
    drop_table(:scores)
  end
end
