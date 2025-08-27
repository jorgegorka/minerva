class McpController < ApplicationController
  def index
    server = MCP::Server.new(
      name: "rails_mcp",
      version: "1.0.0",
      tools: [],
      prompts: [],
      resources: Resources::Finder.call,
      server_context: { user_id: current_user.id }
    )
    render(json: server.handle_json(request.body.read))
  end
end
