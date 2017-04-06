::Sequel.migration do
  up do
    create_table(:scoreboard_history_positions) do
      primary_key :id
      DateTime :created_at, null: false
      json :data
    end
  end

  down do
    drop_table(:scoreboard_history_positions)
  end
end
