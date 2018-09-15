::Sequel.migration do
  up do
    create_table(:teams) do
      primary_key :id
      String :name, size: 100, null: false, unique: true
      String :alias, size: 50, null: false, unique: true
      String :network, size: 18, null: false, unique: true
      TrueClass :guest, null: false, default: false
      String :logo_hash, size: 64, null: true, default: nil
    end
  end

  down do
    drop_table(:teams)
  end
end
