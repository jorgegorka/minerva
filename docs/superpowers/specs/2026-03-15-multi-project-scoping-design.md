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
  has_many :messages, dependent: :destroy
  has_many :tool_calls, dependent: :destroy
end
```

### Migration Strategy

A single migration that:

1. Creates the `projects` table
2. Adds `project_id` columns (nullable initially) to all domain tables
3. Creates a "Default" project
4. Backfills all existing rows to the default project
5. Adds NOT NULL constraints
6. Adds indexes and foreign keys

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
    default_scope { where(project_id: Current.project&.id) if Current.project }
  end
end
```

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

`Current.project` stays nil, so all queries are unscoped. MCP returns documents from all projects.

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

### Navigation

A project switcher dropdown in the nav bar showing:
- Current project name
- List of all projects (via `Project.unscoped.order(:name)`)
- Link to create new project

## Background Jobs & Callbacks

### Jobs

Jobs don't need `Current.project` set. They load records by ID (unscoped), so the default scope doesn't interfere:

- `CreateEmbeddingJob` — loads document by ID, operates on it
- `ProcessPdfAttachmentJob` — same
- `SiteCrawlerJob` / `PageScraperJob` — same

When jobs create child records, they copy `project_id` from the parent:

```ruby
WebPage.create!(project_id: site.project_id, title: ..., content: ...)
```

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

```ruby
# test/test_helper.rb
setup do
  @project = Project.create!(name: "Test Project")
  Current.project = @project
end
```

Ensures existing tests don't break by providing a default project context.
