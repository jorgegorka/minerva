# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

MINERVA is a knowledge management Rails 8.0+ application that serves as a Model Context Protocol (MCP) server, allowing AI systems to access and interact with stored documents and knowledge bases. The application exposes documents, chat history, and vector embeddings through the MCP interface while providing a web UI for document management.

**Key Technologies:**
- Ruby 3.3.6
- Rails ~> 8.0.2  
- PostgreSQL with pgvector extension for vector search
- MCP gem for Model Context Protocol integration
- Solid Queue/Cache/Cable (database-backed, using PostgreSQL)
- Marksmith for rich markdown editing
- Commonmarker for markdown rendering
- Active Storage for file attachments
- Kamal for deployment
- Minitest for testing (not RSpec)

## Essential Development Commands

### Setup & Build
```bash
bundle install                    # Install dependencies
bin/setup                        # Initial project setup (if available)
bin/rails db:prepare             # Prepare all databases (main, cache, queue, cable)
```

### Development Server
```bash
bin/dev                          # Start development server (via bin/rails server)
bin/rails server                # Alternative server start
```

### Testing
```bash
bin/rails test                   # Run unit/integration tests
bin/rails test:system            # Run system tests with headless Chrome
bin/rails db:test:prepare test test:system  # Full test suite (as in CI)
```

### Code Quality & Security
```bash
bin/rubocop                      # Ruby style linting
bin/rubocop -f github            # GitHub Actions format
bin/brakeman --no-pager          # Security vulnerability scan
bin/importmap audit              # JavaScript dependency security scan
```

### Deployment (Kamal)
```bash
bin/kamal deploy                 # Full deployment
bin/kamal app logs -f            # Tail application logs
bin/kamal shell                  # Interactive shell in container
bin/kamal console                # Rails console in production
bin/kamal dbc                    # Database console in production
```

## Architecture

### Knowledge Management Features

The application provides specialized tools for document processing and content extraction:

**Markdown Processing**
- `marksmith` gem provides rich form helpers for markdown editing
- `commonmarker` renders markdown content with sanitization
- Views use `marksmithed` helper for safe HTML rendering

**Content Extraction** (Optional dependencies)
- `metainspector` - Extract metadata from web pages
- `ruby-readability` - Extract readable content from HTML

**File Storage**
- Active Storage integration for document attachments
- Persistent volume mounting in production (`/rails/storage`)

### MCP Integration
The application's core purpose is to serve as an MCP (Model Context Protocol) server. The integration works as follows:

1. **McpController** (`app/controllers/mcp_controller.rb`) handles POST requests to `/mcp/index`
2. **MCP::Server** instantiated with configuration:
   - `name`: "rails_mcp"
   - `version`: "1.0.0" 
   - `resources`: Provided by `Resources::Finder.call`
   - `server_context`: User-specific data
3. **Resources::Finder** (`app/middleware/resources/finder.rb`) converts Documents into MCP resources
4. **Request Processing**: `server.handle_json(request.body.read)` processes MCP protocol messages
5. **Response**: JSON responses conform to MCP specification

To extend MCP functionality:
- Add tools, prompts, or resources to the `MCP::Server` initialization
- Modify `Resources::Finder` to include additional data sources
- The `server_context` can include user-specific data for personalization

### Database Architecture

The application uses **PostgreSQL** as its primary database with the `pgvector` extension enabled for vector similarity search. The schema includes:

**Core Application Tables** (`db/schema.rb`)
- `documents` - User-created knowledge documents (title, content)
- `chats` - Chat conversations with model_id tracking
- `messages` - Individual chat messages with role, content, token counts
- `tool_calls` - Tool invocations with arguments (JSONB)
- `knowledge_documents` - Documents with vector embeddings for similarity search
- Active Storage tables for file attachments

**Solid Gems Infrastructure** (PostgreSQL-backed)
- **Queue Database** (`db/queue_schema.rb`) - Solid Queue job storage
- **Cache Database** (`db/cache_schema.rb`) - Solid Cache key-value storage
- **Cable Database** (`db/cable_schema.rb`) - Solid Cable message storage

**Vector Search Capabilities**
- `pgvector` extension enables semantic search over document content
- `knowledge_documents` table includes `vector(1536)` embedding column
- Support for similarity queries and RAG (Retrieval Augmented Generation)

This architecture eliminates the need for Redis while maintaining Rails' caching and background job capabilities, with PostgreSQL handling all data storage including vector embeddings.

## Testing

The project uses **Minitest** (not RSpec) as the testing framework with the following configuration:

- **Parallel Testing**: Tests run in parallel using `workers: :number_of_processors`
- **System Tests**: Use headless Chrome via Selenium WebDriver
- **Fixtures**: All fixtures loaded for tests (`fixtures :all`)
- **Screenshot Capture**: Failed system tests automatically capture screenshots to `tmp/screenshots/`

### Running Specific Tests
```bash
bin/rails test test/controllers/mcp_controller_test.rb           # MCP controller tests
bin/rails test test/controllers/documents_controller_test.rb     # Document CRUD tests
bin/rails test test/models/document_test.rb                     # Document model tests
bin/rails test test/controllers/mcp_controller_test.rb:4         # Single test method
bin/rails test:system                                           # All system tests (document UI)
```

## Deployment

The application uses **Kamal** for containerized deployment with Docker. Key configuration in `config/deploy.yml`:

### Deployment Configuration
- **Service**: `rails_mcp`
- **Image**: Built for amd64 architecture  
- **SSL**: Automatic Let's Encrypt certificates
- **Queue Processing**: Solid Queue runs inside Puma process (`SOLID_QUEUE_IN_PUMA=true`)
- **Storage**: Persistent volume mounted at `/rails/storage`

### Kamal Commands
```bash
bin/kamal setup                  # Initial server setup
bin/kamal deploy                 # Deploy latest code
bin/kamal rollback               # Rollback to previous version
bin/kamal app exec "rake db:migrate"  # Run migrations
```

### Adding Database/Redis Accessories
Uncomment and configure the accessories section in `config/deploy.yml` to add:
- MySQL/PostgreSQL database servers
- Redis for additional caching/sessions
- Other containerized services

## Development Workflow

### CI Pipeline
The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on PRs and main branch pushes:

1. **Security Scanning**: Brakeman (Ruby) + importmap audit (JS dependencies)
2. **Code Quality**: RuboCop linting with omakase style rules
3. **Testing**: Full test suite with screenshot artifacts on failure

### Code Style
- **RuboCop**: Uses `rubocop-rails-omakase` for opinionated Rails styling
- **Security**: Brakeman scans for common Rails vulnerabilities
- **Dependencies**: importmap audit checks for known JS vulnerabilities

### Adding Application Features
When building on this knowledge management foundation:

1. **Knowledge Models**: Add to `app/models/` - use PostgreSQL main database
2. **Vector Search**: Extend knowledge_documents table or create new embedding tables
3. **MCP Extensions**: Enhance `Resources::Finder` or add tools/prompts to `McpController`
4. **Document Processing**: Add content extraction pipelines using metainspector/ruby-readability
5. **Background Jobs**: Use `ApplicationJob` - processed by Solid Queue (PostgreSQL-backed)
6. **Caching**: Use Rails.cache - backed by Solid Cache (PostgreSQL-backed)
7. **Real-time**: Use ActionCable - backed by Solid Cable (PostgreSQL-backed)

### Database Migrations
```bash
bin/rails generate migration AddEmbeddingToDocuments embedding:vector{1536}
bin/rails db:migrate                    # Main PostgreSQL database
bin/rails db:migrate:cache             # Cache database (rarely needed)
bin/rails db:migrate:queue             # Queue database (rarely needed)
bin/rails db:schema:load               # Load schema (faster than running all migrations)
```

## Key Patterns

- **Environment Variables**: Configure via `config/deploy.yml` env section for production
- **Scaling**: Move Solid Queue to dedicated servers by removing `SOLID_QUEUE_IN_PUMA` and adding job accessories
- **Monitoring**: Use Kamal aliases for log tailing and console access
- **Asset Pipeline**: Uses Propshaft + importmap-rails (no Webpack/Node.js)
