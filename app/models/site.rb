class Site < Document
  validates :url, uniqueness: true, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :max_depth, presence: true, numericality: { greater_than: 0 }
end
