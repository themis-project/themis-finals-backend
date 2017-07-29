::Sequel.migration do
  up do
    create_table(:services) do
      primary_key :id
      String :name, size: 50, null: false, unique: true
      String :alias, size: 50, null: false, unique: true
      Integer :protocol, null: false, default: 0
      String :hostmask, size: 15, null: false
      json :metadata
    end
  end

  down do
    drop_table(:services)
  end
end
