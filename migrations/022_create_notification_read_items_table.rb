::Sequel.migration do
  up do
    create_table(:notification_read_items) do
      primary_key :id
      String :addr, size: 18, null: false, index: true
      foreign_key :notification_id, :notifications, null: false, index: true
      unique [:addr, :notification_id]
    end
  end

  down do
    drop_table(:notification_read_items)
  end
end
