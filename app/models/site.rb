class Site < Document
  validates :url, uniqueness: true, allow_blank: false
  validates :max_depth, presence: true, numericality: { greater_than: 0 }
end
