require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get mcp_index_url
    assert_response :success
  end
end
