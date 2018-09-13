::Sequel.migration do
  up do
    create_table(:configurations) do
      primary_key :id
      json :data
      DateTime :created, null: false
    end
  end

  down do
    drop_table(:configurations)
  end
end
