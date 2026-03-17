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
