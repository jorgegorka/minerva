require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  test "should post to index" do
    post mcp_index_url, params: { jsonrpc: "2.0", method: "resources/list", id: 1 }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :success
  end
end
