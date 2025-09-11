class AddMaxDepthToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :max_depth, :integer
  end
end
