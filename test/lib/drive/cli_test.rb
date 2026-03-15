# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"

class DriveCliTest < Minitest::Test
  BIN = File.expand_path("../../../bin/drive", __dir__)
  SESSION_NAME = "drive_cli_test_#{$$}"

  def setup
    system("tmux kill-session -t #{SESSION_NAME} 2>/dev/null")
  end

  def teardown
    system("tmux kill-session -t #{SESSION_NAME} 2>/dev/null")
  end

  def drive(*args)
    stdout, stderr, status = Open3.capture3(BIN, *args)
    [stdout, stderr, status]
  end

  def drive_json(*args)
    stdout, _stderr, _status = drive(*args, "--json")
    JSON.parse(stdout)
  end

  def test_session_create_and_list_json
    result = drive_json("session", "create", SESSION_NAME, "--detach")
    assert result["ok"]
    assert_equal SESSION_NAME, result["session"]

    list = drive_json("session", "list")
    assert list["ok"]
    names = list["sessions"].map { |s| s["name"] }
    assert_includes names, SESSION_NAME
  end

  def test_session_kill_json
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    result = drive_json("session", "kill", SESSION_NAME)
    assert result["ok"]
  end

  def test_session_create_duplicate_fails
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    result = drive_json("session", "create", SESSION_NAME, "--detach")
    refute result["ok"]
    assert_equal "session_exists", result["error"]
  end

  def test_run_command_json
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    result = drive_json("run", SESSION_NAME, "echo hello_cli")
    assert result["ok"]
    assert_equal 0, result["exit_code"]
    assert_match(/hello_cli/, result["output"])
  end

  def test_run_command_nonzero_exit
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    result = drive_json("run", SESSION_NAME, "bash -c 'exit 2'")
    refute result["ok"]
    assert_equal 2, result["exit_code"]
  end

  def test_send_command_json
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    result = drive_json("send", SESSION_NAME, "echo sent_test")
    assert result["ok"]
    assert_equal "send", result["action"]
  end

  def test_logs_command_json
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    drive("run", SESSION_NAME, "echo logs_test_output", "--json")
    result = drive_json("logs", SESSION_NAME)
    assert result["ok"]
    assert_match(/logs_test_output/, result["content"])
  end

  def test_poll_command_json
    drive("session", "create", SESSION_NAME, "--detach", "--json")
    drive("send", SESSION_NAME, "echo POLL_READY", "--json")
    sleep 0.5
    result = drive_json("poll", SESSION_NAME, "--until", "POLL_READY", "--timeout", "5")
    assert result["ok"]
    assert_match(/POLL_READY/, result["match"])
  end

  def test_fanout_command_json
    s1 = "#{SESSION_NAME}_a"
    s2 = "#{SESSION_NAME}_b"
    drive("session", "create", s1, "--detach", "--json")
    drive("session", "create", s2, "--detach", "--json")

    result = drive_json("fanout", "echo fanout_ok", "--targets", "#{s1},#{s2}")
    assert result["ok"]
    assert_equal 2, result["results"].length

    system("tmux kill-session -t #{s1} 2>/dev/null")
    system("tmux kill-session -t #{s2} 2>/dev/null")
  end
end
