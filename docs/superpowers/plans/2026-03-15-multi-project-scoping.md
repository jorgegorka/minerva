# Multi-Project Scoping Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scope all application content by project using session-based selection and `default_scope` via `Current.project`.

**Architecture:** A `ProjectScoped` concern adds a conditional `default_scope` to all domain models. `Current.project` (set by `ApplicationController` from session) drives scoping in the web app. When nil (MCP, jobs, console), queries return all records. Full denormalization with `project_id` on every domain table.

**Tech Stack:** Rails 8.0, PostgreSQL with pgvector, ActiveSupport::CurrentAttributes, Solid Queue

**Spec:** `docs/superpowers/specs/2026-03-15-multi-project-scoping-design.md`

---

## File Structure

### New Files
- `app/models/project.rb` — Project model with validations and associations
- `app/models/current.rb` — CurrentAttributes for thread-local project
- `app/models/concerns/project_scoped.rb` — Concern with default_scope and belongs_to :project
- `app/controllers/projects_controller.rb` — CRUD + switch action
- `app/views/projects/index.html.erb` — Projects listing page
- `app/views/projects/new.html.erb` — New project form
- `app/views/projects/_form.html.erb` — Shared form partial
- `app/views/layouts/_project_switcher.html.erb` — Nav dropdown partial
- `db/migrate/XXXXXXXX_add_multi_project_scoping.rb` — Migration
- `test/fixtures/projects.yml` — Project fixtures
- `test/models/project_test.rb` — Project model tests
- `test/models/concerns/project_scoped_test.rb` — Concern tests
- `test/controllers/projects_controller_test.rb` — Controller tests

### Modified Files
- `app/models/document.rb` — Add ProjectScoped concern, cross-project category validation
- `app/models/category.rb` — Add ProjectScoped concern
- `app/models/chat.rb` — Add ProjectScoped concern
- `app/models/message.rb` — Add ProjectScoped concern, denormalization callback
- `app/models/tool_call.rb` — Add ProjectScoped concern, denormalization callback
- `app/models/site.rb` — Scope url uniqueness to project_id
- `app/models/web_page.rb` — Scope url uniqueness to project_id
- `app/controllers/application_controller.rb` — Add set_current_project before_action
- `app/controllers/mcp_controller.rb` — Skip set_current_project
- `app/controllers/consoles_controller.rb` — Skip set_current_project
- `app/views/layouts/_navigation.html.erb` — Add project switcher
- `app/jobs/application_job.rb` — Add before_perform to clear Current.project
- `app/jobs/site_crawler_job.rb` — Accept site_id, pass project_id
- `app/jobs/page_scraper_job.rb` — Accept project_id parameter
- `app/middleware/web_pages/scraper.rb` — Accept and use project_id
- `app/middleware/web_pages/site_crawler.rb` — Accept and pass project_id
- `config/routes.rb` — Add project routes
- `test/test_helper.rb` — Add project setup/teardown
- `test/fixtures/documents.yml` — Add project references
- `test/fixtures/categories.yml` — Add project references

---

## Chunk 1: Database & Core Models

### Task 1: Migration

**Files:**
- Create: `db/migrate/XXXXXXXX_add_multi_project_scoping.rb`

- [ ] **Step 1: Generate the migration**

Run: `bin/rails generate migration AddMultiProjectScoping`

- [ ] **Step 2: Write the migration**

Edit the generated migration file:

```ruby
class AddMultiProjectScoping < ActiveRecord::Migration[8.1]
  def up
    # 1. Create projects table
    create_table :projects do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :projects, :name, unique: true

    # 2. Add nullable project_id to all domain tables
    add_reference :documents, :project, null: true, foreign_key: true, index: true
    add_reference :categories, :project, null: true, foreign_key: true, index: true
    add_reference :chats, :project, null: true, foreign_key: true, index: true
    add_reference :messages, :project, null: true, foreign_key: true, index: true
    add_reference :tool_calls, :project, null: true, foreign_key: true, index: true

    # 3. Create default project and backfill
    project = execute("INSERT INTO projects (name, created_at, updated_at) VALUES ('Default', NOW(), NOW()) RETURNING id")
    project_id = project.first["id"]

    execute("UPDATE documents SET project_id = #{project_id} WHERE project_id IS NULL")
    execute("UPDATE categories SET project_id = #{project_id} WHERE project_id IS NULL")
    execute("UPDATE chats SET project_id = #{project_id} WHERE project_id IS NULL")
    execute("UPDATE messages SET project_id = #{project_id} WHERE project_id IS NULL")
    execute("UPDATE tool_calls SET project_id = #{project_id} WHERE project_id IS NULL")

    # 4. Add NOT NULL constraints
    change_column_null :documents, :project_id, false
    change_column_null :categories, :project_id, false
    change_column_null :chats, :project_id, false
    change_column_null :messages, :project_id, false
    change_column_null :tool_calls, :project_id, false

    # 5. Replace url unique indexes with compound (project_id, url) indexes
    # Documents table has STI — Site and WebPage both validate url uniqueness
    # No existing unique index on url in schema, only model-level validation
    # Add compound index for database-level enforcement
    add_index :documents, [:project_id, :url], unique: true, where: "url IS NOT NULL", name: "index_documents_on_project_id_and_url"
  end

  def down
    remove_index :documents, name: "index_documents_on_project_id_and_url"
    remove_reference :tool_calls, :project
    remove_reference :messages, :project
    remove_reference :chats, :project
    remove_reference :categories, :project
    remove_reference :documents, :project
    drop_table :projects
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully, schema.rb updated with projects table and project_id columns.

- [ ] **Step 4: Verify schema**

Run: `bin/rails db:migrate:status`
Expected: All migrations show "up" status.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_multi_project_scoping.rb db/schema.rb
git commit -m "feat: add multi-project scoping migration"
```

---

### Task 2: Project Model

**Files:**
- Create: `test/models/project_test.rb`
- Create: `app/models/project.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/project_test.rb`:

```ruby
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid with a name" do
    project = Project.new(name: "My Project")
    assert project.valid?
  end

  test "invalid without a name" do
    project = Project.new(name: nil)
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "invalid with a duplicate name" do
    Project.create!(name: "Unique Name")
    project = Project.new(name: "Unique Name")
    assert_not project.valid?
    assert_includes project.errors[:name], "has already been taken"
  end

  test "has many documents" do
    assert_respond_to projects(:default), :documents
  end

  test "has many categories" do
    assert_respond_to projects(:default), :categories
  end

  test "has many chats" do
    assert_respond_to projects(:default), :chats
  end

  test "has many messages" do
    assert_respond_to projects(:default), :messages
  end

  test "has many tool_calls" do
    assert_respond_to projects(:default), :tool_calls
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/project_test.rb`
Expected: FAIL — Project class not defined or fixture missing.

- [ ] **Step 3: Create the project fixture**

Create `test/fixtures/projects.yml`:

```yaml
default:
  name: "Test Project"

other:
  name: "Other Project"
```

- [ ] **Step 4: Write the Project model**

Create `app/models/project.rb`:

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

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/project_test.rb`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/project.rb test/models/project_test.rb test/fixtures/projects.yml
git commit -m "feat: add Project model with validations and associations"
```

---

### Task 3: Current Class

**Files:**
- Create: `app/models/current.rb`

- [ ] **Step 1: Create the Current class**

Create `app/models/current.rb`:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :project
end
```

- [ ] **Step 2: Verify it loads**

Run: `bin/rails runner "puts Current.respond_to?(:project)"`
Expected: `true`

- [ ] **Step 3: Commit**

```bash
git add app/models/current.rb
git commit -m "feat: add Current class for thread-local project attribute"
```

---

### Task 4: ProjectScoped Concern

**Files:**
- Create: `test/models/concerns/project_scoped_test.rb`
- Create: `app/models/concerns/project_scoped.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/concerns/project_scoped_test.rb`:

```ruby
require "test_helper"

class ProjectScopedTest < ActiveSupport::TestCase
  setup do
    @project_a = projects(:default)
    @project_b = projects(:other)
  end

  teardown do
    Current.project = nil
  end

  test "scopes queries when Current.project is set" do
    Current.project = @project_a
    category_a = Category.create!(title: "Scoped A", project: @project_a)
    Category.create!(title: "Scoped B", project: @project_b)

    assert_includes Category.all, category_a
    assert_equal 1, Category.where(title: ["Scoped A", "Scoped B"]).count
  end

  test "returns all records when Current.project is nil" do
    Current.project = nil
    category_a = Category.create!(title: "Global A", project: @project_a)
    category_b = Category.create!(title: "Global B", project: @project_b)

    assert_includes Category.all, category_a
    assert_includes Category.all, category_b
  end

  test "belongs_to project" do
    category = categories(:development)
    assert_respond_to category, :project
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/concerns/project_scoped_test.rb`
Expected: FAIL — ProjectScoped concern not defined, Category doesn't have project association.

- [ ] **Step 3: Write the ProjectScoped concern**

Create `app/models/concerns/project_scoped.rb`:

```ruby
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :project
    default_scope -> { Current.project ? where(project_id: Current.project.id) : all }
    before_validation { self.project_id ||= Current.project&.id }
  end
end
```

The `before_validation` auto-populates `project_id` from `Current.project` when creating records in the web app. Without this, every `Model.create!` call would need an explicit `project:` parameter. This makes record creation seamless — controllers don't need to pass `project_id` manually.

- [ ] **Step 4: Add ProjectScoped to Category model**

Edit `app/models/category.rb` — add `include ProjectScoped` after class definition:

```ruby
class Category < ApplicationRecord
  include ProjectScoped

  has_many :documents, dependent: :destroy

  validates :title, presence: true
end
```

- [ ] **Step 5: Update category fixtures with project references**

Edit `test/fixtures/categories.yml`:

```yaml
development:
  title: Development
  project: default

design:
  title: Design
  project: default

documentation:
  title: Documentation
  project: default
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/concerns/project_scoped_test.rb`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/models/concerns/project_scoped.rb test/models/concerns/project_scoped_test.rb app/models/category.rb test/fixtures/categories.yml
git commit -m "feat: add ProjectScoped concern and apply to Category"
```

---

### Task 5: Apply ProjectScoped to All Models

**Files:**
- Modify: `app/models/document.rb`
- Modify: `app/models/chat.rb`
- Modify: `app/models/message.rb`
- Modify: `app/models/tool_call.rb`
- Modify: `app/models/site.rb`
- Modify: `app/models/web_page.rb`
- Modify: `test/fixtures/documents.yml`

- [ ] **Step 1: Add ProjectScoped to Document**

Edit `app/models/document.rb` — make these specific changes:

1. Add `include ProjectScoped` after line 2 (`include Embeddable`)
2. Add `validate :category_belongs_to_same_project, if: -> { category_id.present? }` after line 6 (`validates :title, presence: true`)
3. Add the `category_belongs_to_same_project` method inside the existing `private` block (after the `file_attachment_changed?` method):

```ruby
    def category_belongs_to_same_project
      if category && category.project_id != project_id
        errors.add(:category, "must belong to the same project")
      end
    end
```

Do NOT remove or replace any existing methods (`enqueue_pdf_processing`, `initialize_file_tracking`, `file_attachment_changed?`). Only add the new lines.

- [ ] **Step 2: Add ProjectScoped to Chat**

Edit `app/models/chat.rb`:

```ruby
class Chat < ApplicationRecord
  include ProjectScoped

  acts_as_chat
end
```

- [ ] **Step 3: Add ProjectScoped to Message with denormalization**

Edit `app/models/message.rb`:

```ruby
class Message < ApplicationRecord
  include ProjectScoped

  acts_as_message

  before_validation { self.project_id = chat.project_id if project_id.blank? && chat }
end
```

- [ ] **Step 4: Add ProjectScoped to ToolCall with denormalization**

Edit `app/models/tool_call.rb`:

```ruby
class ToolCall < ApplicationRecord
  include ProjectScoped

  acts_as_tool_call

  before_validation { self.project_id = message.project_id if project_id.blank? && message }
end
```

- [ ] **Step 5: Update Site url uniqueness scope**

Edit `app/models/site.rb`:

```ruby
class Site < Document
  validates :url, uniqueness: { scope: :project_id }, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :max_depth, presence: true, numericality: { greater_than: 0 }
end
```

- [ ] **Step 6: Update WebPage url uniqueness scope**

Edit `app/models/web_page.rb`:

```ruby
class WebPage < Document
  validates :url, uniqueness: { scope: :project_id }, allow_nil: true
end
```

- [ ] **Step 7: Update document fixtures with project references**

Edit `test/fixtures/documents.yml` — add `project: default` to every fixture:

```yaml
# Base document fixtures for existing tests
one:
  title: MyString
  content: MyText
  project: default

two:
  title: MyString
  content: MyText
  project: default

# Asset fixtures
asset_one:
  type: Asset
  title: Sample Asset
  content: This is sample asset content
  category: development
  project: default

asset_two:
  type: Asset
  title: Another Asset
  content: Another asset content
  category: design
  project: default

# Text fixtures
text_one:
  type: Text
  title: Sample Text
  content: This is sample text content
  category: development
  project: default

text_two:
  type: Text
  title: Another Text
  content: Another text content
  category: documentation
  project: default

# Site fixtures
site_one:
  type: Site
  title: Example Site
  url: https://example.com
  max_depth: 2
  category: development
  project: default

site_two:
  type: Site
  title: Another Site
  url: https://another-example.com
  max_depth: 3
  category: documentation
  project: default

# Plain document for general tests
plain_document:
  title: Plain Document
  content: Plain document content
  project: default
```

- [ ] **Step 8: Run all model tests**

Run: `bin/rails test test/models/`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/models/document.rb app/models/chat.rb app/models/message.rb app/models/tool_call.rb app/models/site.rb app/models/web_page.rb test/fixtures/documents.yml
git commit -m "feat: apply ProjectScoped to all domain models"
```

---

### Task 6: Test Helper Setup/Teardown

**Files:**
- Modify: `test/test_helper.rb`

- [ ] **Step 1: Add project setup and teardown**

Edit `test/test_helper.rb`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      @project = projects(:default)
      Current.project = @project
    end

    teardown do
      Current.project = nil
    end
  end
end
```

- [ ] **Step 2: Run the full test suite**

Run: `bin/rails test`
Expected: All existing tests PASS (model + controller tests). Some may fail if controllers don't have project context yet — that's expected and will be fixed in Chunk 2.

- [ ] **Step 3: Commit**

```bash
git add test/test_helper.rb
git commit -m "feat: add project setup/teardown to test helper"
```

---

### Task 7: ApplicationJob Safety

**Files:**
- Modify: `app/jobs/application_job.rb`

- [ ] **Step 1: Add before_perform callback**

Edit `app/jobs/application_job.rb` — add `before_perform { Current.project = nil }` after the `retry_on ActiveRecord::Deadlocked` line (line 3). Do not change anything else. The result should be:

```ruby
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encounter a deadlock
  retry_on ActiveRecord::Deadlocked

  before_perform { Current.project = nil }

  discard_on ActiveJob::DeserializationError
end
```

- [ ] **Step 2: Run job tests**

Run: `bin/rails test test/jobs/`
Expected: All job tests PASS.

- [ ] **Step 3: Commit**

```bash
git add app/jobs/application_job.rb
git commit -m "feat: clear Current.project in background jobs"
```

---

## Chunk 2: Controller Layer

### Task 8: ApplicationController — set_current_project

**Files:**
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Add set_current_project before_action**

Edit `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_project

  private

  def current_user
    # TODO: Implement proper user authentication
    @current_user ||= Struct.new(:id).new(1)
  end

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
end
```

- [ ] **Step 2: Skip set_current_project in MCP controller**

Edit `app/controllers/mcp_controller.rb` — add `skip_before_action :set_current_project` as the first line inside the class. Do not add or remove any other lines.

```ruby
class McpController < ApplicationController
  skip_before_action :set_current_project

  # ... rest unchanged ...
end
```

- [ ] **Step 3: Skip set_current_project in Consoles controller**

Edit `app/controllers/consoles_controller.rb` — add skip at the top of the class:

```ruby
class ConsolesController < ApplicationController
  skip_before_action :set_current_project

  # ... rest unchanged ...
end
```

- [ ] **Step 4: Run controller tests to check current state**

Run: `bin/rails test test/controllers/`
Expected: Some tests may fail because there's no project in the test DB yet / no routes for projects. Note which fail — they'll be fixed in subsequent tasks.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/controllers/mcp_controller.rb app/controllers/consoles_controller.rb
git commit -m "feat: add set_current_project to ApplicationController"
```

---

### Task 9: ProjectsController & Routes

**Files:**
- Create: `test/controllers/projects_controller_test.rb`
- Create: `app/controllers/projects_controller.rb`
- Create: `app/views/projects/new.html.erb`
- Create: `app/views/projects/_form.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/projects_controller_test.rb`:

```ruby
require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:default)
    @other_project = projects(:other)
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: { project: { name: "Brand New Project" } }
    end

    created_project = Project.unscoped.order(created_at: :desc).first
    assert_equal created_project.id, session[:project_id]
    assert_redirected_to root_url
  end

  test "should not create project without name" do
    assert_no_difference("Project.count") do
      post projects_url, params: { project: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should switch project" do
    post switch_project_url(@other_project)
    assert_equal @other_project.id, session[:project_id]
    assert_redirected_to root_url
  end

  test "new is accessible when no projects exist" do
    Project.unscoped.delete_all
    get new_project_url
    assert_response :success
  end

  test "create is accessible when no projects exist" do
    Project.unscoped.delete_all
    assert_difference("Project.count") do
      post projects_url, params: { project: { name: "First Project" } }
    end
    assert_redirected_to root_url
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/projects_controller_test.rb`
Expected: FAIL — routes and controller not defined.

- [ ] **Step 3: Add routes**

Edit `config/routes.rb` — add the `resources :projects` block after the `mount MissionControl::Jobs::Engine` line and before `resources :assets`. Do not remove any existing routes or comments:

```ruby
  resources :projects, only: [:index, :new, :create] do
    member do
      post :switch
    end
  end
```

- [ ] **Step 4: Create the ProjectsController**

Create `app/controllers/projects_controller.rb`:

```ruby
class ProjectsController < ApplicationController
  skip_before_action :set_current_project, only: [:new, :create]

  def index
    @projects = Project.unscoped.order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      session[:project_id] = @project.id
      Current.project = @project
      redirect_to root_url, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def switch
    project = Project.unscoped.find(params[:id])
    session[:project_id] = project.id
    Current.project = project
    redirect_to root_url, notice: "Switched to #{project.name}."
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end
end
```

- [ ] **Step 5: Create project views**

Create `app/views/projects/index.html.erb`:

```erb
<div class="container mt-4">
  <h1>Projects</h1>
  <ul>
    <% @projects.each do |project| %>
      <li>
        <%= project.name %>
        <% if project == Current.project %>
          (current)
        <% else %>
          <%= button_to "Switch", switch_project_path(project), method: :post, class: "btn btn--small" %>
        <% end %>
      </li>
    <% end %>
  </ul>
  <%= link_to "New Project", new_project_path, class: "btn btn--primary" %>
</div>
```

Create `app/views/projects/_form.html.erb`:

```erb
<%= form_with(model: project) do |form| %>
  <% if project.errors.any? %>
    <div class="alert alert--error">
      <ul>
        <% project.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-group">
    <%= form.label :name %>
    <%= form.text_field :name, class: "input", autofocus: true %>
  </div>

  <div class="form-group">
    <%= form.submit class: "btn btn--primary" %>
  </div>
<% end %>
```

Create `app/views/projects/new.html.erb`:

```erb
<div class="container mt-4">
  <h1>New Project</h1>
  <%= render "form", project: @project %>
</div>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/projects_controller_test.rb`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/projects_controller.rb test/controllers/projects_controller_test.rb app/views/projects/ config/routes.rb
git commit -m "feat: add ProjectsController with CRUD and switch action"
```

---

### Task 10: Navigation Project Switcher

**Files:**
- Create: `app/views/layouts/_project_switcher.html.erb`
- Modify: `app/views/layouts/_navigation.html.erb`

- [ ] **Step 1: Create the project switcher partial**

The app uses custom BEM CSS classes (`site-nav__*`), not Bootstrap. Use a `<details>`/`<summary>` element for the dropdown (pure CSS, no JS required).

Create `app/views/layouts/_project_switcher.html.erb`:

```erb
<% if Current.project %>
  <li class="site-nav__item">
    <details class="site-nav__dropdown">
      <summary class="site-nav__link site-nav__dropdown-toggle">
        <%= Current.project.name %>
      </summary>
      <ul class="site-nav__dropdown-menu">
        <% Project.unscoped.order(:name).each do |project| %>
          <li>
            <% if project == Current.project %>
              <span class="site-nav__dropdown-item site-nav__dropdown-item--active"><%= project.name %></span>
            <% else %>
              <%= button_to project.name, switch_project_path(project), method: :post, class: "site-nav__dropdown-item" %>
            <% end %>
          </li>
        <% end %>
        <li class="site-nav__dropdown-divider"></li>
        <li><%= link_to "New Project", new_project_path, class: "site-nav__dropdown-item" %></li>
      </ul>
    </details>
  </li>
<% end %>
```

- [ ] **Step 2: Add dropdown CSS styles**

Edit `app/assets/stylesheets/navigation.css` — add these styles inside the `@layer components { ... }` block, before the closing `}`:

```css
  /* ========================================
   * Project Switcher Dropdown
   * ======================================== */
  .site-nav__dropdown {
    position: relative;
  }

  .site-nav__dropdown-toggle {
    cursor: pointer;
    list-style: none;
    user-select: none;
  }

  .site-nav__dropdown-toggle::-webkit-details-marker,
  .site-nav__dropdown-toggle::marker {
    display: none;
  }

  .site-nav__dropdown-toggle::after {
    content: " \25BE";
    font-size: 0.8em;
  }

  .site-nav__dropdown-menu {
    background: var(--nav-bg);
    backdrop-filter: blur(12px) saturate(1.2);
    border: 1px solid var(--nav-border);
    border-radius: var(--radius-md, 0.5rem);
    box-shadow: var(--nav-shadow);
    list-style: none;
    margin: 0;
    min-inline-size: 12rem;
    padding: var(--space-xs, 0.25rem) 0;
    position: absolute;
    right: 0;
    top: 100%;
    z-index: calc(var(--z-bar) + 1);
  }

  .site-nav__dropdown-item {
    all: unset;
    color: var(--color-ink-light);
    cursor: pointer;
    display: block;
    font-family: var(--font-sans);
    font-size: var(--text-small);
    padding: var(--space-xs, 0.25rem) var(--space-md, 1rem);
    transition: var(--transition-normal);
    transition-property: color, background-color;
    width: 100%;
    box-sizing: border-box;
  }

  .site-nav__dropdown-item:hover {
    background: oklch(var(--lch-sage-lightest));
    color: var(--color-ink);
  }

  .site-nav__dropdown-item--active {
    color: oklch(var(--lch-sage-dark));
    font-weight: 600;
  }

  .site-nav__dropdown-divider {
    border-top: 1px solid var(--nav-border);
    margin: var(--space-xs, 0.25rem) 0;
  }

  /* button_to generates a form wrapper — style it inline */
  .site-nav__dropdown-menu form {
    display: contents;
  }
```

- [ ] **Step 3: Add switcher to navigation**

Edit `app/views/layouts/_navigation.html.erb` — add the project switcher render call as the last `<li>` inside the `<ul class="site-nav__menu">` (after the Consoles item, before the closing `</ul>` on line 25):

```erb
      <%= render "layouts/project_switcher" %>
```

The nav's `<ul>` should end like this:

```erb
      <li class="site-nav__item">
        <%= link_to "Consoles", consoles_path, class: nav_link_class("consoles") %>
      </li>
      <%= render "layouts/project_switcher" %>
    </ul>
```

- [ ] **Step 4: Verify visually**

Run: `bin/dev` and open the app in a browser. Verify the project switcher appears in the navigation as the last item, and clicking it opens a dropdown with project names.

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/_project_switcher.html.erb app/views/layouts/_navigation.html.erb app/assets/stylesheets/navigation.css
git commit -m "feat: add project switcher to navigation"
```

---

### Task 11: Run Full Test Suite & Fix Failures

**Files:**
- Various test files may need minor fixes

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: Note any failures. Common issues will be:
- Controller tests creating records without `project_id` (should be handled by `Current.project` in test setup)
- MCP controller test (should pass since we skip `set_current_project`)

- [ ] **Step 2: Fix any failing tests**

Address each failure. The test helper's `setup` block sets `Current.project`, so model creations in tests should automatically pick up the project via `default_scope`. If any test explicitly creates records without going through the model (e.g., raw SQL), fix those.

- [ ] **Step 3: Run tests again to confirm all pass**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

Stage only the specific files you fixed (do not use `git add -A` as it may stage unrelated files):

```bash
git add <specific files that were fixed>
git commit -m "fix: resolve test failures after multi-project scoping"
```

---

## Chunk 3: Site Crawling Pipeline & MCP Integration Tests

### Task 12: Update Site Crawling Pipeline

**Files:**
- Modify: `app/jobs/site_crawler_job.rb`
- Modify: `app/jobs/page_scraper_job.rb`
- Modify: `app/middleware/web_pages/site_crawler.rb`
- Modify: `app/middleware/web_pages/scraper.rb`

- [ ] **Step 1: Update SiteCrawlerJob to accept site_id**

Edit `app/jobs/site_crawler_job.rb`:

```ruby
class SiteCrawlerJob < ApplicationJob
  queue_as :default

  def perform(site_id)
    site = Site.unscoped.find(site_id)
    WebPages::SiteCrawler.new(site.url, max_depth: site.max_depth, project_id: site.project_id).crawl
  end
end
```

- [ ] **Step 2: Update SiteCrawler to accept and pass project_id**

Edit `app/middleware/web_pages/site_crawler.rb`:

```ruby
module WebPages
  class SiteCrawler
    def initialize(start_url, max_depth: 2, project_id:)
      @start_url = start_url
      @domain = URI.parse(start_url).host
      @max_depth = max_depth
      @project_id = project_id
      @visited = Set.new
    end

    def crawl(url = start_url, depth = 0)
      return if depth > @max_depth || visited.include?(url)

      visited << url

      doc = Nokogiri::HTML(HTTParty.get(url).body)
      return unless doc

      PageScraperJob.perform_later(url, project_id)

      internal_links(doc).each do |link|
        crawl(link, depth + 1)
        sleep 0.4
      end
    end

    private

    attr_reader :visited, :start_url, :domain, :max_depth, :project_id

    def internal_links(doc)
      doc.css("a[href]").map { |a| a["href"] }
        .map { |href| URI.join(start_url, href).to_s rescue nil }
        .compact
        .select { |u| URI.parse(u).host == domain }
    end
  end
end
```

- [ ] **Step 3: Update PageScraperJob to accept project_id**

Edit `app/jobs/page_scraper_job.rb`:

```ruby
class PageScraperJob < ApplicationJob
  queue_as :default

  def perform(url, project_id)
    WebPages::Scraper.new(url, project_id: project_id).scrape
  end
end
```

- [ ] **Step 4: Update Scraper to accept and use project_id**

Edit `app/middleware/web_pages/scraper.rb`:

```ruby
require "httparty"
require "nokogiri"
require "readability"

module WebPages
  class Scraper
    def initialize(url, project_id:)
      @url = url
      @project_id = project_id
    end

    def scrape
      response = HTTParty.get(url, headers: { "User-Agent" => "MinervaBot/1.0" })
      return unless response.success?

      html = response.body
      document = Nokogiri::HTML(html)

      title = document.at("title")&.text&.strip

      readability_doc = Readability::Document.new(html, tags: %w[div section article p h1 h2 h3 h4 h5 h6])
      content_html    = readability_doc.content

      cleaned_content = ActionController::Base.helpers.strip_tags(content_html)

      WebPage.create!(
        url:,
        title:,
        content: cleaned_content,
        project_id: project_id
      )
    rescue => e
      Rails.logger.error("Failed to scrape #{url}: #{e.message}")
      nil
    end

    private

    attr_reader :url, :project_id
  end
end
```

- [ ] **Step 5: Check for call sites**

No code in `app/` currently calls `SiteCrawlerJob.perform_later` — the SitesController does not enqueue crawling jobs on create. If you find any call sites via `grep -r "SiteCrawlerJob.perform_later" app/`, update them to pass `site.id` instead of `(site.url, site.max_depth)`.

- [ ] **Step 6: Update SiteCrawler tests**

Edit `test/middleware/web_pages/site_crawler_test.rb` — all `SiteCrawler.new` calls must include `project_id:`. The `setup` block and every test that creates a `SiteCrawler` need updating.

In `setup` (line 6), change:
```ruby
@crawler = WebPages::SiteCrawler.new(@start_url, max_depth: 2)
```
to:
```ruby
@crawler = WebPages::SiteCrawler.new(@start_url, max_depth: 2, project_id: projects(:default).id)
```

Update every other `SiteCrawler.new` call in the file the same way. There are instances at:
- Line 14: `WebPages::SiteCrawler.new(@start_url)` → `WebPages::SiteCrawler.new(@start_url, project_id: projects(:default).id)`
- Line 24: `WebPages::SiteCrawler.new(@start_url, max_depth: 5)` → `WebPages::SiteCrawler.new(@start_url, max_depth: 5, project_id: projects(:default).id)`
- Line 37: `WebPages::SiteCrawler.new(url)` → `WebPages::SiteCrawler.new(url, project_id: projects(:default).id)`
- Line 171: `WebPages::SiteCrawler.new(start_url, max_depth: 1)` → `WebPages::SiteCrawler.new(start_url, max_depth: 1, project_id: projects(:default).id)`

- [ ] **Step 7: Update Scraper tests**

Edit `test/middleware/web_pages/scraper_test.rb` — the `Scraper.new` call and all `WebPage.create!` calls need `project_id`.

In `setup` (line 6), change:
```ruby
@scraper = WebPages::Scraper.new(@url)
```
to:
```ruby
@scraper = WebPages::Scraper.new(@url, project_id: projects(:default).id)
```

For all `WebPage.create!` calls in the file (lines 23, 36, 55, 67), add `project: projects(:default)`:
```ruby
# Example: line 23
WebPage.create!(
  url: @url,
  title: "Test Title",
  content: "Test content",
  project: projects(:default)
)
```

Apply the same pattern to every `WebPage.create!` and `WebPage.new` call in the file.

- [ ] **Step 8: Run crawler-related tests**

Run: `bin/rails test test/jobs/ test/middleware/`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/jobs/site_crawler_job.rb app/jobs/page_scraper_job.rb app/middleware/web_pages/site_crawler.rb app/middleware/web_pages/scraper.rb test/middleware/
git commit -m "feat: thread project_id through site crawling pipeline"
```

---

### Task 13: MCP Integration Tests

**Files:**
- Modify: `test/controllers/mcp_controller_test.rb`

- [ ] **Step 1: Add MCP global scoping tests**

Edit `test/controllers/mcp_controller_test.rb` — add tests verifying MCP returns documents from all projects. Important: the test helper sets `Current.project` in setup, so MCP tests must explicitly clear it. Also, `Asset.create!` will fail validation because `Asset` requires a file attachment — build the asset, attach the file, then save.

```ruby
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
```

- [ ] **Step 2: Run MCP tests**

Run: `bin/rails test test/controllers/mcp_controller_test.rb`
Expected: All tests PASS. The MCP controller skips `set_current_project`, so `Current.project` is nil and `default_scope` returns all records.

- [ ] **Step 3: Commit**

```bash
git add test/controllers/mcp_controller_test.rb
git commit -m "test: add MCP global scoping integration test"
```

---

### Task 14: Final Full Test Suite Pass

- [ ] **Step 1: Run the complete test suite**

Run: `bin/rails test`
Expected: ALL tests PASS.

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses.

- [ ] **Step 3: Run security scan**

Run: `bin/brakeman --no-pager`
Expected: No new warnings.

- [ ] **Step 4: Fix any issues found**

Address any remaining test failures, lint warnings, or security issues.

- [ ] **Step 5: Final commit**

Stage only the specific files you fixed (do not use `git add -A`):

```bash
git add <specific files that were fixed>
git commit -m "chore: pass full test suite, linter, and security scan"
```
