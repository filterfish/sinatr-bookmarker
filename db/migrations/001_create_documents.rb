# -*- encoding: utf-8 -*-
Sequel.migration do
  change do
    create_table(:documents) do
      String    :uri, :null => false
      String    :redirected_uri
      String    :title
      String    :domain
      String    :html
      String    :content
      Integer   :status

      primary_key :id
      index :uri, :unique => true
    end
    DB.run 'ALTER TABLE "documents" ADD COLUMN "download_date" timestamp DEFAULT current_timestamp NOT NULL'
  end
end
