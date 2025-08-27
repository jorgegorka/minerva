class Document < ApplicationRecord
  validates :title, presence: true
  validates :content, presence: true
  validates :url, uniqueness: true, allow_blank: true
end
