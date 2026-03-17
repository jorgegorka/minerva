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
    [ ToolCall, Message, Chat, Document, Category ].each { |m| m.unscoped.delete_all }
    Project.unscoped.delete_all
    get new_project_url
    assert_response :success
  end

  test "create is accessible when no projects exist" do
    [ ToolCall, Message, Chat, Document, Category ].each { |m| m.unscoped.delete_all }
    Project.unscoped.delete_all
    assert_difference("Project.count") do
      post projects_url, params: { project: { name: "First Project" } }
    end
    assert_redirected_to root_url
  end
end
