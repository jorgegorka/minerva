# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/drive/errors"

class Drive::ErrorsTest < Minitest::Test
  def test_drive_error_has_code_and_to_h
    error = Drive::DriveError.new("something broke")
    assert_equal "error", error.code
    assert_equal({ ok: false, error: "error", message: "something broke" }, error.to_h)
  end

  def test_tmux_not_found_error
    error = Drive::TmuxNotFoundError.new
    assert_equal "tmux_not_found", error.code
    assert_match(/tmux not found/, error.message)
  end

  def test_session_not_found_error
    error = Drive::SessionNotFoundError.new("agent-1")
    assert_equal "session_not_found", error.code
    assert_match(/agent-1/, error.message)
    h = error.to_h
    assert_equal "agent-1", h[:session]
  end

  def test_session_exists_error
    error = Drive::SessionExistsError.new("agent-1")
    assert_equal "session_exists", error.code
    assert_match(/already exists/, error.message)
  end

  def test_command_timeout_error
    error = Drive::CommandTimeoutError.new(session: "agent-1", cmd: "npm test", timeout: 30.0)
    assert_equal "timeout", error.code
    assert_match(/timed out/, error.message)
    h = error.to_h
    assert_equal "agent-1", h[:session]
    assert_equal 30.0, h[:timeout]
  end

  def test_tmux_command_error
    error = Drive::TmuxCommandError.new(args: ["kill-session", "-t", "x"], stderr: "no session")
    assert_equal "tmux_error", error.code
    assert_match(/no session/, error.message)
  end

  def test_pattern_not_found_error
    error = Drive::PatternNotFoundError.new(pattern: "READY", session: "agent-1", timeout: 10.0)
    assert_equal "pattern_not_found", error.code
    assert_match(/READY/, error.message)
  end

  def test_process_not_found_error_by_pid
    error = Drive::ProcessNotFoundError.new(pid: 12345)
    assert_equal "process_not_found", error.code
    assert_match(/12345/, error.message)
  end

  def test_process_not_found_error_by_name
    error = Drive::ProcessNotFoundError.new(name: "node")
    assert_equal "process_not_found", error.code
    assert_match(/node/, error.message)
  end

  def test_kill_permission_error
    error = Drive::KillPermissionError.new(pid: 99)
    assert_equal "kill_permission_denied", error.code
    assert_match(/99/, error.message)
  end
end
