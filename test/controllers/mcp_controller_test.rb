require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    # MCP is global — must clear project scoping set by test_helper
    Current.project = nil
  end

  test "should post to index" do
    post mcp_index_url, params: { jsonrpc: "2.0", method: "resources/list", id: 1 }.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :success
  end

  test "MCP returns resources from all projects" do
    project_a = projects(:default)
    project_b = projects(:other)

    # Asset requires file attachment — build, attach, then save
    asset_a = Asset.new(title: "Asset A", content: "Content A", project: project_a)
    asset_a.file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.pdf")), filename: "a.pdf", content_type: "application/pdf")
    asset_a.save!

    asset_b = Asset.new(title: "Asset B", content: "Content B", project: project_b)
    asset_b.file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.pdf")), filename: "b.pdf", content_type: "application/pdf")
    asset_b.save!

    post mcp_index_url, params: { jsonrpc: "2.0", method: "resources/list", id: 1 }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    resource_names = body.dig("result", "resources")&.map { |r| r["name"] } || []

    assert_includes resource_names, "Asset A"
    assert_includes resource_names, "Asset B"
  end
end
