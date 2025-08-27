module WebPages
  class SiteCrawler
    def initialize(start_url, max_depth: 2)
      @start_url = start_url
      @domain = URI.parse(start_url).host
      @max_depth = max_depth
      @visited = Set.new
    end

    def crawl(url = start_url, depth = 0)
      return if depth > @max_depth || visited.include?(url)

      visited << url
      page = WebPageScraper.new(url).scrape
      return unless page

      doc = Nokogiri::HTML(HTTParty.get(url).body)
      internal_links(doc).each do |link|
        crawl(link, depth + 1)
        sleep 0.4
      end
    end

    private

    attr_reader :visited, :start_url, :domain, :max_depth

    def internal_links(doc)
      doc.css("a[href]").map { |a| a["href"] }
        .map { |href| URI.join(start_url, href).to_s rescue nil }
        .compact
        .select { |u| URI.parse(u).host == domain }
    end
  end
end
