class PageScraperJob < ApplicationJob
  queue_as :default

  def perform(url)
    WebPages::Scraper.new(url).scrape
  end
end
