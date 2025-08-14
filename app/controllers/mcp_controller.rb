class McpController < ApplicationController
  def index
    server = MCP::Server.new(
      name: "Ruby on Rails development",
      version: "1.0.0",
      tools: [],
      prompts: [],
      resources:,
      server_context: {},
    )
    server.resources_read_handler do |params|
      Resources::Finder.call params[:uri].downcase
    end

    render json: server.handle_json(request.body.read)
  end

  private

  def resources
    Resources::Builder.call
  end
end
