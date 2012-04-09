Sequel.migration do
  change do
    create_table(:users) do
      String    :login, :null => false
      String    :name, :null => false
      String    :token, :null => false
      DateTime  :created_at, :null => false
      DateTime  :updated_at, :null => false

      primary_key :id
    end

    now = Time.now.utc
    self[:users].insert(:login => 'filterfish', :name => 'Richard Heycock', :token => '8778828a97f43bf9c178fd3622caedfbc89e62a4aef75cc5fb81e7d2956c1f0c', :created_at => now, :updated_at => now)
  end
end
