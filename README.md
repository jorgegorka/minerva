# MINERVA

A Rails 8 MCP (Model Context Protocol) server that provides a knowledge base for AI agents. Elevate your AI applications with enhanced reasoning and dynamic tool usage through RAG-powered document retrieval.

<img width="963" height="931" alt="minerva" src="https://github.com/user-attachments/assets/ae4c3469-f79d-4b73-83b4-939af23bb3c9" />



## Features

- **Multi-Project Support** — Organize your knowledge base into separate projects with automatic data isolation and easy switching
- **Document Management** — Create and organize markdown documents via web UI
- **PDF Processing** — Upload PDFs with automatic text extraction
- **Website Scraping** — Import content from web pages and crawl entire sites
- **RAG Search** — Vector similarity search powered by pgvector embeddings
- **MCP Interface** — Connect directly to Claude, Cursor, or any MCP-compatible AI agent
- **Drive CLI** — Tmux-based terminal automation for managing sessions, running commands, and process management
- **Console UI** — Web-based terminal session viewer with live output, process monitoring, and session management

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

1. **Create a Project** — Set up a project to organize your knowledge base (all content is scoped per project)
2. **Add Documents** — Use the web UI to create markdown documents or upload PDFs
3. **Scrape Websites** — Add site URLs to automatically import their content
4. **Organize** — Use categories to organize your knowledge base
5. **Query** — Your AI agent can search and retrieve relevant documents via the `DocumentSearch` tool

> **Note:** The MCP endpoint at `/mcp` serves documents globally across all projects, so your AI agent has access to your entire knowledge base regardless of which project is active in the UI.

## Drive CLI

Drive is a tmux-based terminal automation tool for managing sessions, running commands, and monitoring processes. Entry point: `bin/drive`.

**Key commands:**

| Command | Description |
|---------|-------------|
| `drive session create NAME` | Create a new tmux session |
| `drive session list` | List all tmux sessions |
| `drive session kill NAME` | Kill a tmux session |
| `drive run SESSION CMD` | Run a command and wait for completion |
| `drive send SESSION TEXT` | Send raw keystrokes to a session |
| `drive logs SESSION` | Capture pane output |
| `drive poll SESSION` | Wait for output matching a pattern |
| `drive fanout CMD` | Run a command across multiple sessions in parallel |
| `drive proc list` | List processes with filtering |
| `drive proc kill PID` | Kill processes by PID or name |
| `drive proc tree PID` | Show process tree |

**Console UI** — A web interface at `/consoles` lets you view tmux sessions, monitor running processes, and send commands directly from the browser.

## Development

```bash
bin/dev                          # Start development server
bin/rails test                   # Run tests
bin/rubocop                      # Lint Ruby code
bin/brakeman --no-pager          # Security scan
```

## Architecture

- **Multi-Project Scoping** — `Current.project` and `ProjectScoped` concern provide automatic per-project data isolation
- **PostgreSQL** with pgvector for vector storage (768-dim embeddings, HNSW index)
- **Solid Queue/Cache/Cable** for background jobs and caching (no Redis required)
- **Propshaft + importmap-rails** for assets (no Node.js required)
- **Drive CLI** — Tmux automation layer in `lib/drive/` with web console at `/consoles`
- **Kamal** for deployment

## Contributors

- [Mario Alvarez](https://github.com/marioalna)
- [Jorge Alvarez](https://github.com/jorgegorka)

## License

MIT
