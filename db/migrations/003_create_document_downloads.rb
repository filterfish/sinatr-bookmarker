# -*- encoding: utf-8 -*-
Sequel.migration do
  change do
    create_table(:document_downloads) do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :document_id, :documents
    end
    DB.run 'ALTER TABLE "document_downloads" ADD COLUMN "date" timestamp DEFAULT current_timestamp NOT NULL'
  end
end
