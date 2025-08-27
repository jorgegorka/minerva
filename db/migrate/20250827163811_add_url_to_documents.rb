class AddUrlToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :url, :string
  end
end
