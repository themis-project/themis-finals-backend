::Sequel.migration do
  up do
    create_table(:competition_stages) do
      primary_key :id
      Integer :stage, null: false, default: 0
      DateTime :created_at, null: false
    end
  end

  down do
    drop_table(:competition_stages)
  end
end
