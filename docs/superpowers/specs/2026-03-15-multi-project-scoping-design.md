# Multi-Project Scoping Design

## Overview

Scope all application content by project. Users select a project on entry (auto-selecting last used), and all queries are scoped to that project via `default_scope`. The MCP endpoint remains global, searching across all projects.

## Decisions

- **Project selection persistence:** Session-based. URLs stay the same.
- **MCP scoping:** Global. MCP searches across all projects.
- **Chat scoping:** Chats belong to a project.
- **Denormalization:** Full. `project_id` on every domain table, including child tables (messages, tool_calls).
- **First visit behavior:** Auto-select last used project (from session/cookie). If no session, select oldest project. If no projects exist, redirect to create one.
- **Project attributes:** Name only (plus timestamps).

## Approach

Default scope with `Current.project` (Approach A). A `ProjectScoped` concern applies `default_scope` conditionally — when `Current.project` is set (web app), everything is scoped; when nil (MCP, jobs, console), queries are unscoped.

## Data Model

### New Table: `projects`

| Column       | Type     | Constraints          |
|-------------|----------|----------------------|
| id          | bigint   | PK                   |
| name        | string   | NOT NULL, UNIQUE     |
| created_at  | datetime |                      |
| updated_at  | datetime |                      |

### Add `project_id` to Existing Tables

All domain tables get a `project_id` column:

- `documents` (covers Asset, Site, Text, WebPage via STI)
- `categories`
- `chats`
- `messages`
- `tool_calls`

Each column: `bigint, NOT NULL, indexed, foreign key to projects`.

### Project Model

```ruby
class Project < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :documents, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :messages, dependent: :destroy   # denormalized shortcut (canonical: project -> chats -> messages)
  has_many :tool_calls, dependent: :destroy # denormalized shortcut (canonical: project -> chats -> messages -> tool_calls)
end
```

The `messages` and `tool_calls` associations are intentional denormalized shortcuts. The canonical path is through `chats`, but direct associations enable simpler project-scoped queries without joins.

### Migration Strategy

A single migration that:

1. Creates the `projects` table
2. Adds `project_id` columns (nullable initially) to all domain tables
3. Creates a "Default" project
4. Backfills all existing rows to the default project
5. Adds NOT NULL constraints
6. Adds indexes and foreign keys
7. Replaces any existing unique indexes on `url` with compound indexes on `(project_id, url)`

This is safe as a single migration because PostgreSQL DDL is transactional. Acceptable for current data volume; would need to be split into multiple migrations for a production system with significant data.

## Scoping Mechanism

### Current Class

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :project
end
```

### ProjectScoped Concern

```ruby
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :project
    default_scope -> { Current.project ? where(project_id: Current.project.id) : all }
  end
end
```

The lambda must always return a valid `ActiveRecord::Relation`. When `Current.project` is nil, returning `all` ensures an unscoped relation rather than `nil` (which has undefined behavior across Rails versions).

Behavior by context:

| Context         | `Current.project` | Scoping behavior |
|----------------|-------------------|------------------|
| Web app        | Set               | Scoped to project |
| MCP controller | Nil               | Global (all records) |
| Background jobs| Nil               | Global (load by ID) |
| Rails console  | Nil               | Global (set manually if needed) |

### Models That Get the Concern

- Document (and all STI subtypes: Asset, Site, Text, WebPage)
- Category
- Chat
- Message
- ToolCall

### Uniqueness Validations

After scoping, uniqueness validations must be scoped to `project_id`:

- `Site` — `validates :url, uniqueness: { scope: :project_id }` (same URL allowed in different projects)
- `WebPage` — `validates :url, uniqueness: { scope: :project_id }`
- `Project` — `validates :name, uniqueness: true` (project names are globally unique)

Any database unique indexes on `url` must become compound indexes on `(project_id, url)`.

### Cross-Project Safety

A document's `category_id` must reference a category in the same project. Add a validation:

```ruby
# In Document
validate :category_belongs_to_same_project, if: -> { category_id.present? }

private

def category_belongs_to_same_project
  if category && category.project_id != project_id
    errors.add(:category, "must belong to the same project")
  end
end
```

Categories are project-specific. Switching projects shows a different category list. The same category name can exist in multiple projects.

## Controller Layer

### ApplicationController

```ruby
before_action :set_current_project

private

def set_current_project
  project = if session[:project_id]
    Project.unscoped.find_by(id: session[:project_id])
  end

  project ||= Project.unscoped.order(:created_at).first

  if project
    session[:project_id] = project.id
    Current.project = project
  else
    redirect_to new_project_path
  end
end
```

### MCP Controller

```ruby
skip_before_action :set_current_project
```

`Current.project` stays nil, so the `default_scope` returns `all` (unscoped). MCP returns documents from all projects. This means `Resources::Finder` (`Asset.all`), `Tools::DocumentSearch` (`Document.nearest_neighbors`), and any other MCP middleware query globally. Integration tests must verify this behavior explicitly.

### Consoles Controller

```ruby
skip_before_action :set_current_project
```

Drive console sessions are not project-scoped.

### ProjectsController

New controller with:

- `index` — list all projects (for switcher UI)
- `new` / `create` — create a new project
- `switch` — custom action: sets `session[:project_id]`, redirects back

`ProjectsController` must skip `set_current_project` for `new` and `create` actions to avoid an infinite redirect loop when no projects exist:

```ruby
skip_before_action :set_current_project, only: [:new, :create]
```

### Navigation

A project switcher dropdown in the nav bar showing:
- Current project name
- List of all projects (via `Project.unscoped.order(:name)`)
- Link to create new project

## Background Jobs & Callbacks

### Jobs

Because the `default_scope` returns `all` when `Current.project` is nil, jobs can safely use `Document.find(id)` without scoping issues. However, if Solid Queue runs in-process (dev/test), `Current.project` could theoretically leak from a web request thread. To be safe, jobs should clear `Current.project` at the start:

```ruby
# In ApplicationJob
before_perform { Current.project = nil }
```

**Jobs that create records must pass `project_id` explicitly:**

- `CreateEmbeddingJob` — loads document by ID, operates on it (no new records)
- `ProcessPdfAttachmentJob` — same
- `SiteCrawlerJob` — must receive `site_id` (not just URL/depth) so it can pass `project_id` through to child jobs
- `PageScraperJob` — must receive `project_id` as a parameter and pass it to `WebPages::Scraper`

### Site Crawling Pipeline

The current pipeline passes only URL through the chain: `SiteCrawlerJob(url, depth)` -> `SiteCrawler` -> `PageScraperJob(url)` -> `Scraper` -> `WebPage.create!(...)`. After scoping, `project_id` must flow through:

1. `SiteCrawlerJob` receives `site_id` instead of just URL. Loads the site, gets `project_id` and URL from it.
2. `WebPages::SiteCrawler` accepts and passes `project_id` to child `PageScraperJob` calls.
3. `PageScraperJob` receives `(url, project_id)` and passes `project_id` to `Scraper`.
4. `WebPages::Scraper` accepts `project_id` and includes it in `WebPage.create!(project_id: project_id, ...)`.

Without this, `WebPage.create!` will fail the NOT NULL constraint on `project_id`.

### Denormalization Sync

Child records inherit `project_id` from their parent via `before_validation`:

```ruby
# In Message
before_validation { self.project_id = chat.project_id if project_id.blank? }

# In ToolCall
before_validation { self.project_id = message.project_id if project_id.blank? }
```

## Testing Strategy

### Migration Test

Verify the migration runs cleanly — existing data backfilled to default project, NOT NULL constraints hold.

### Model Tests

- `ProjectScoped` concern: when `Current.project` is set, queries scoped; when nil, queries return all records
- Associations: `project.documents`, `project.categories`, etc.
- Denormalization callbacks: messages inherit `project_id` from chat, tool_calls from message

### Controller Tests

- All existing controller tests still pass (records need a project in setup)
- Project switching: `session[:project_id]` updates, subsequent requests scope correctly
- Auto-select: first visit picks oldest project
- No projects: redirect to `new_project_path`
- MCP controller: returns documents across all projects

### Integration Tests

Full flow: create project -> create document -> switch project -> document not visible -> switch back -> document visible.

### Test Helper

Use a fixture for the default project rather than creating records in setup:

```yaml
# test/fixtures/projects.yml
default:
  name: "Test Project"
```

All existing fixtures must reference the default project (e.g., `project: default`).

In `test_helper.rb`:

```ruby
setup do
  @project = projects(:default)
  Current.project = @project
end

teardown do
  Current.project = nil
end
```

The `teardown` prevents `Current.project` from leaking between tests (especially with parallel test runners).

### MCP Integration Tests

Verify that when `Current.project` is nil (MCP context):
- `Resources::Finder` returns assets from all projects
- `Tools::DocumentSearch` searches documents across all projects
- `Document.nearest_neighbors` is not filtered by project
