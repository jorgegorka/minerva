# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Rails 8.0+ application that integrates with Model Context Protocol (MCP) via the `mcp` gem. The application uses modern Rails defaults including Solid Cache, Solid Queue, and Solid Cable for background processing and caching, all backed by SQLite in development.

**Key Technologies:**
- Ruby 3.3.6
- Rails ~> 8.0.2  
- MCP gem for Model Context Protocol integration
- Solid Queue/Cache/Cable (database-backed replacements for Redis)
- PostgresSQL
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

### MCP Integration
The application's core purpose is to serve as an MCP (Model Context Protocol) server. The integration works as follows:

1. **McpController** (`app/controllers/mcp_controller.rb`) handles POST requests to `/mcp/index`
2. **MCP::Server** is instantiated with configuration (name, version, tools, prompts, resources)
3. **Request Processing**: `server.handle_json(request.body.read)` processes MCP protocol messages
4. **Response**: JSON responses conform to MCP specification

To extend MCP functionality:
- Add tools, prompts, or resources to the `MCP::Server` initialization
- Consider creating service objects in `app/services/` for complex MCP logic
- The `server_context` can include user-specific data for personalization

### Database Architecture with Solid Gems

The application uses three separate SQLite databases:

**Main Database** (`db/schema.rb` - not yet present)
- Application-specific models and data
- User data, business logic tables

**Queue Database** (`db/queue_schema.rb`)
- `solid_queue_jobs` - Background job storage
- `solid_queue_*_executions` - Job execution states
- `solid_queue_recurring_tasks` - Scheduled/cron jobs
- `solid_queue_processes` - Worker process management

**Cache Database** (`db/cache_schema.rb`)  
- `solid_cache_entries` - Key-value cache storage

**Cable Database** (`db/cable_schema.rb`)
- `solid_cable_messages` - WebSocket/ActionCable message storage

This architecture eliminates the need for Redis while maintaining Rails' caching and background job capabilities.

## Testing

The project uses **Minitest** (not RSpec) as the testing framework with the following configuration:

- **Parallel Testing**: Tests run in parallel using `workers: :number_of_processors`
- **System Tests**: Use headless Chrome via Selenium WebDriver
- **Fixtures**: All fixtures loaded for tests (`fixtures :all`)
- **Screenshot Capture**: Failed system tests automatically capture screenshots to `tmp/screenshots/`

### Running Specific Tests
```bash
bin/rails test test/controllers/mcp_controller_test.rb           # Single test file
bin/rails test test/controllers/mcp_controller_test.rb:4         # Single test method
bin/rails test:system                                           # All system tests
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
When building on this MCP foundation:

1. **Models**: Add to `app/models/` - migrations will use the main database
2. **MCP Extensions**: Enhance `McpController` or create MCP-specific service objects
3. **Background Jobs**: Use `ApplicationJob` - jobs will be processed by Solid Queue
4. **Caching**: Use Rails.cache - backed by Solid Cache
5. **Real-time**: Use ActionCable - backed by Solid Cable

### Database Migrations
```bash
bin/rails generate migration CreateUsers name:string email:string
bin/rails db:migrate                    # Main database
bin/rails db:migrate:cache             # Cache database (rarely needed)
bin/rails db:migrate:queue             # Queue database (rarely needed)
```

## Key Patterns

- **Environment Variables**: Configure via `config/deploy.yml` env section for production
- **Scaling**: Move Solid Queue to dedicated servers by removing `SOLID_QUEUE_IN_PUMA` and adding job accessories
- **Monitoring**: Use Kamal aliases for log tailing and console access
- **Asset Pipeline**: Uses Propshaft + importmap-rails (no Webpack/Node.js)
