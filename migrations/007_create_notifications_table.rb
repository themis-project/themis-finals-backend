::Sequel.migration do
  up do
    create_table(:notifications) do
      primary_key :id
      String :title, size: 100, null: false
      String :description, text: true, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      foreign_key :team_id, :teams, index: true, null: true
    end
  end

  down do
    drop_table(:notifications)
  end
end
