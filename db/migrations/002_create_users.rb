Sequel.migration do
  change do
    create_table(:users) do
      String    :login, :null => false
      String    :name, :null => false
      DateTime  :created_at, :null => false
      DateTime  :updated_at, :null => false

      primary_key :id
    end

    now = Time.now.utc
    self[:users].insert(:login => 'filterfish', :name => 'Richard Heycock', :created_at => now, :updated_at => now)
  end
end
