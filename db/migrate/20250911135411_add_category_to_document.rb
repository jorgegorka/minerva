class AddCategoryToDocument < ActiveRecord::Migration[8.0]
  def change
    add_reference :documents, :category, null: true
  end
end
