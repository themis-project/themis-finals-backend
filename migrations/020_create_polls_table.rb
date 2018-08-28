::Sequel.migration do
  up do
    create_table(:polls) do
      primary_key :id
      DateTime :created_at, null: false

      foreign_key :round_id, :rounds, index: true, null: false
    end
  end

  down do
    drop_table(:polls)
  end
end
