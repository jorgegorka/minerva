class Document < ApplicationRecord
  has_neighbors :embedding

  validates :title, presence: true
  validates :content, presence: true

  scope :search, ->(query) {
    where("to_tsvector(content) @@ plainto_tsquery(?)", query)
      .order(Arel.sql("ts_rank_cd(to_tsvector(content), plainto_tsquery(?)) DESC", query))
  }
end
