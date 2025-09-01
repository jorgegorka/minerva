class EmbeddingsForDocuments < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    add_column :documents, :embedding, :vector, limit: 768
    add_column :documents, :embedding_md5, :string
    add_column :documents, :embedding_generated_at, :datetime
    add_column :documents, :embedding_dimensions, :integer

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
