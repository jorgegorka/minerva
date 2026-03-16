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
