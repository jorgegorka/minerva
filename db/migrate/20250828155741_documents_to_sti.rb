class DocumentsToSti < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :type, :string
    add_index :documents, :type
  end
end
