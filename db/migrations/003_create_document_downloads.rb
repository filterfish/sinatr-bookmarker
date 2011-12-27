Sequel.migration do
  change do
    create_table(:document_downloads) do
      DateTime  :download_at, :null => false

      primary_key :id
      foreign_key :user_id, :users
      foreign_key :document_id, :documents
    end
  end
end
