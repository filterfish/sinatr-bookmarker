Sequel.migration do
  change do
    create_table(:documents) do
      String    :uri, :null => false
      String    :title
      String    :domain
      String    :content
      DateTime  :created_at, :null => false
      DateTime  :updated_at, :null => false

      primary_key :id
      index :uri, :unique => true
      index :domain, :unique => true
    end
  end
end
