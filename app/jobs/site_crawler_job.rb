class SiteCrawlerJob < ApplicationJob
  queue_as :default

  def perform(url, depth)
    WebPages::SiteCrawler.new(url, max_depth: depth).crawl
  end
end
