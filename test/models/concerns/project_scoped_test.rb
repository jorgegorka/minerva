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
