# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MINERVA is a Rails 8.0 MCP (Model Context Protocol) server that provides a knowledge base for AI agents. It enables AI systems to access and interact with stored documents through the MCP interface, with RAG capabilities via pgvector embeddings.

## Development Commands

```bash
bin/dev                          # Start development server
bin/rails test                   # Run unit/integration tests
bin/rails test:system            # Run system tests (headless Chrome)
bin/rails test test/path:line    # Run single test at specific line
bin/rubocop                      # Lint Ruby code
bin/brakeman --no-pager          # Security scan
bin/importmap audit              # JS dependency audit
```

## Architecture

### MCP Server Flow
`POST /mcp/index` → `McpController` → `MCP::Server` with:
- **Resources**: `Resources::Finder` converts `Asset` records to MCP resources
- **Tools**: `Tools::Finder` registers tools like `DocumentSearch` for RAG queries

### Document Processing Pipeline
1. Documents created via web UI (`DocumentsController`)
2. PDF attachments trigger `ProcessPdfAttachmentJob` for content extraction
3. Content changes trigger `CreateEmbeddingJob` which uses `Documents::Embedding`
4. Embeddings generated via Ollama (`nomic-embed-text:v1.5`) stored as pgvector

### Key Models
- `Document` - Base model with vector embeddings (`has_neighbors :embedding`), full-text search, PDF attachment support
- `Asset` - STI subclass of Document, exposed as MCP resources
- `Chat`/`Message`/`ToolCall` - Chat history tracking

### Middleware Pattern
Service objects in `app/middleware/` use `Callable` module for `ClassName.call(...)` syntax:
- `Documents::Embedding` - Generate and store embeddings
- `Tools::DocumentSearch` - Vector similarity search via `nearest_neighbors`
- `WebPages::Scraper`, `WebPages::SiteCrawler` - Content extraction

### Infrastructure
- PostgreSQL with pgvector extension (768-dim vectors, HNSW index)
- Solid Queue/Cache/Cable (all PostgreSQL-backed, no Redis)
- Propshaft + importmap-rails (no Node.js)
- Kamal for deployment
