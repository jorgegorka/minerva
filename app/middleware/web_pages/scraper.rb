require "httparty"
require "nokogiri"
require "readability"

module WebPages
  class Scraper
    def initialize(url)
      @url = url
    end

    def scrape
      response = HTTParty.get(url, headers: { "User-Agent" => "MinervaBot/1.0" })
      return unless response.success?

      html = response.body
      document = Nokogiri::HTML(html)

      title = document.at("title")&.text&.strip

      readability_doc = Readability::Document.new(html, tags: %w[div section article p h1 h2 h3 h4 h5 h6])
      content_html    = readability_doc.content

      cleaned_content = ActionController::Base.helpers.strip_tags(content_html)

      Document.create!(
        url:,
        title:,
        content: cleaned_content
      )
    rescue => e
      Rails.logger.error("Failed to scrape #{url}: #{e.message}")
      nil
    end

    private

    attr_reader :url
  end
end
