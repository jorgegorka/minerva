# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/drive/tmux"

class Drive::TmuxTest < Minitest::Test
  def test_require_tmux_returns_path
    path = Drive::Tmux.require_tmux
    assert path.is_a?(String)
    assert path.include?("tmux")
  end

  def test_resolve_target_without_pane
    assert_equal "mysession:", Drive::Tmux.resolve_target("mysession")
  end

  def test_resolve_target_with_pane
    assert_equal "mysession:.2", Drive::Tmux.resolve_target("mysession", "2")
  end

  def test_session_info_data_class
    info = Drive::Tmux::SessionInfo.new(name: "test", windows: 1, created: "now", attached: false)
    assert_equal "test", info.name
    assert_equal 1, info.windows
    h = info.to_h
    assert_equal "test", h[:name]
  end
end

class Drive::TmuxIntegrationTest < Minitest::Test
  SESSION_NAME = "drive_test_#{$$}"

  def setup
    system("tmux kill-session -t #{SESSION_NAME} 2>/dev/null")
  end

  def teardown
    system("tmux kill-session -t #{SESSION_NAME} 2>/dev/null")
  end

  def test_create_list_kill_session
    Drive::Tmux.create_session(SESSION_NAME, detach: true)
    assert Drive::Tmux.session_exists?(SESSION_NAME)

    sessions = Drive::Tmux.list_sessions
    names = sessions.map(&:name)
    assert_includes names, SESSION_NAME

    Drive::Tmux.kill_session(SESSION_NAME)
    refute Drive::Tmux.session_exists?(SESSION_NAME)
  end

  def test_create_duplicate_session_raises
    Drive::Tmux.create_session(SESSION_NAME, detach: true)
    assert_raises(Drive::SessionExistsError) do
      Drive::Tmux.create_session(SESSION_NAME, detach: true)
    end
  end

  def test_require_session_raises_for_missing
    assert_raises(Drive::SessionNotFoundError) do
      Drive::Tmux.require_session("nonexistent_#{$$}")
    end
  end

  def test_send_keys_and_capture_pane
    Drive::Tmux.create_session(SESSION_NAME, detach: true)
    Drive::Tmux.send_keys(SESSION_NAME, "echo HELLO_DRIVE_TEST", enter: true, literal: false)
    sleep 0.5
    content = Drive::Tmux.capture_pane(SESSION_NAME)
    assert_match(/HELLO_DRIVE_TEST/, content)
  end

  def test_capture_pane_with_scrollback
    Drive::Tmux.create_session(SESSION_NAME, detach: true)
    Drive::Tmux.send_keys(SESSION_NAME, "echo LINE_ONE", enter: true, literal: false)
    sleep 0.3
    content = Drive::Tmux.capture_pane(SESSION_NAME, start_line: -50)
    assert_match(/LINE_ONE/, content)
  end
end
