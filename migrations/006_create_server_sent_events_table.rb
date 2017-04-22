::Sequel.migration do
  up do
    create_table(:server_sent_events) do
      primary_key :id
      String :name, size: 100, null: false
      json :data
      DateTime :created, null: false
    end
  end

  down do
    drop_table(:server_sent_events)
  end
end
