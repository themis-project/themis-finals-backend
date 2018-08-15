::Sequel.migration do
  up do
    create_table(:services) do
      primary_key :id
      String :name, size: 50, null: false, unique: true
      String :alias, size: 50, null: false, unique: true
      String :hostmask, size: 15, null: false
      String :checker_endpoint, size: 256, null: false
    end
  end

  down do
    drop_table(:services)
  end
end
