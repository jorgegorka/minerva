# test class for finder
#
require "test_helper"

class Resources::FinderTest < ActiveSupport::TestCase
  def setup
    @finder = Resources::Finder.new("file:///docs/README.md")
  end

  test "should initialize with a URI" do
    assert_equal [], @finder.call
  end
end
