# MINERVA

A Rails 8 MCP (Model Context Protocol) server that provides a knowledge base for AI agents. Elevate your AI applications with enhanced reasoning and dynamic tool usage through RAG-powered document retrieval.

## Features

- **Document Management** - Create and organize markdown documents via web UI
- **PDF Processing** - Upload PDFs with automatic text extraction
- **Website Scraping** - Import content from web pages and crawl entire sites
- **RAG Search** - Vector similarity search powered by pgvector embeddings
- **MCP Interface** - Connect directly to Claude, Cursor, or any MCP-compatible AI agent

## Requirements

- Ruby 3.4.6
- PostgreSQL 15+ with [pgvector](https://github.com/pgvector/pgvector) extension
- [Ollama](https://ollama.ai) (for local embeddings)

## Installation

```bash
# Clone the repository
git clone https://github.com/your-org/minerva.git
cd minerva

# Install dependencies
bundle install

# Set up environment variables (optional, defaults work for local development)
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password
export POSTGRES_HOST=127.0.0.1

# Set up database with pgvector
bin/rails db:prepare

# Pull the embedding model
ollama pull nomic-embed-text:v1.5

# Start the server
bin/dev
```

The web interface will be available at `http://localhost:3000`.

## Connecting to AI Agents

Minerva exposes an MCP endpoint at `POST /mcp`. Configure your AI agent to connect:

### Claude Code

Add to your `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "minerva": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

### Cursor

Add to your MCP settings:

```json
{
  "minerva": {
    "url": "http://localhost:3000/mcp"
  }
}
```

## Usage

1. **Add Documents** - Use the web UI to create markdown documents or upload PDFs
2. **Scrape Websites** - Add site URLs to automatically import their content
3. **Organize** - Use categories to organize your knowledge base
4. **Query** - Your AI agent can now search and retrieve relevant documents via the `DocumentSearch` tool

## Development

```bash
bin/dev                          # Start development server
bin/rails test                   # Run tests
bin/rubocop                      # Lint Ruby code
bin/brakeman --no-pager          # Security scan
```

## Architecture

- **PostgreSQL** with pgvector for vector storage (768-dim embeddings, HNSW index)
- **Solid Queue/Cache/Cable** for background jobs and caching (no Redis required)
- **Propshaft + importmap-rails** for assets (no Node.js required)
- **Kamal** for deployment

## Contributors

- [Mario Alvarez](https://github.com/marioalna)
- [Jorge Alvarez](https://github.com/jorgegorka)

## License

MIT
