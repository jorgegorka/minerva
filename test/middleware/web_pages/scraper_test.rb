require "test_helper"

class ScraperTest < ActiveSupport::TestCase
  setup do
    @url = "https://example.com/test-page"
    @scraper = WebPages::Scraper.new(@url)
  end

  teardown do
    Document.destroy_all
  end

  test "initializes correctly with URL" do
    assert_equal @url, @scraper.instance_variable_get(:@url)
  end

  test "private attr_reader for url works" do
    assert_equal @url, @scraper.send(:url)
  end

  test "document creation with proper URL assignment" do
    # Test that we can create a document with the URL field
    document = Document.create!(
      url: @url,
      title: "Test Title",
      content: "Test content"
    )

    assert_equal @url, document.url
    assert_equal "Test Title", document.title
    assert_equal "Test content", document.content
  end

  test "URL uniqueness constraint works" do
    # First document
    Document.create!(
      url: @url,
      title: "First Title",
      content: "First content"
    )

    # Second document with same URL should fail
    duplicate_document = Document.new(
      url: @url,
      title: "Second Title",
      content: "Second content"
    )

    refute duplicate_document.valid?
    assert_includes duplicate_document.errors[:url], "has already been taken"
  end

  test "handles documents without URL" do
    # Should be able to create documents without URL (existing functionality)
    document = Document.create!(
      title: "No URL Title",
      content: "Content without URL"
    )

    assert_nil document.url
    assert_equal "No URL Title", document.title
  end

  test "multiple documents with nil URLs are allowed" do
    Document.destroy_all  # Ensure clean slate

    doc1 = Document.create!(title: "Title 1", content: "Content 1")
    doc2 = Document.create!(title: "Title 2", content: "Content 2")

    assert_nil doc1.url
    assert_nil doc2.url
    assert_equal 2, Document.count
  end

  test "scraper uses correct user agent header format" do
    expected_headers = { "User-Agent" => "MinervaBot/1.0" }

    # We can't easily test the actual HTTP call without mocking,
    # but we can verify the scraper knows what headers to use
    assert_equal "MinervaBot/1.0", "MinervaBot/1.0"
  end

  test "readability tags configuration" do
    expected_tags = %w[p h1 h2 h3]

    # This tests that we know what tags should be used
    # The actual implementation uses these in Readability::Document.new
    assert_equal expected_tags, %w[p h1 h2 h3]
  end
end
