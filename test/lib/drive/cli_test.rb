# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "securerandom"

class DriveCliTest < Minitest::Test
  BIN = File.expand_path("../../../bin/drive", __dir__)

  def setup
    @session = "drive_cli_#{$$}_#{SecureRandom.hex(4)}"
  end

  def teardown
    system("tmux kill-session -t #{@session} 2>/dev/null")
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
    result = drive_json("session", "create", @session, "--detach")
    assert result["ok"]
    assert_equal @session, result["session"]

    list = drive_json("session", "list")
    assert list["ok"]
    names = list["sessions"].map { |s| s["name"] }
    assert_includes names, @session
  end

  def test_session_kill_json
    drive("session", "create", @session, "--detach", "--json")
    result = drive_json("session", "kill", @session)
    assert result["ok"]
  end

  def test_session_create_duplicate_fails
    drive("session", "create", @session, "--detach", "--json")
    result = drive_json("session", "create", @session, "--detach")
    refute result["ok"]
    assert_equal "session_exists", result["error"]
  end

  def test_run_command_json
    drive("session", "create", @session, "--detach", "--json")
    result = drive_json("run", @session, "echo hello_cli")
    assert result["ok"]
    assert_equal 0, result["exit_code"]
    assert_match(/hello_cli/, result["output"])
  end

  def test_run_command_nonzero_exit
    drive("session", "create", @session, "--detach", "--json")
    result = drive_json("run", @session, "bash -c 'exit 2'")
    refute result["ok"]
    assert_equal 2, result["exit_code"]
  end

  def test_send_command_json
    drive("session", "create", @session, "--detach", "--json")
    result = drive_json("send", @session, "echo sent_test")
    assert result["ok"]
    assert_equal "send", result["action"]
  end

  def test_logs_command_json
    drive("session", "create", @session, "--detach", "--json")
    drive("run", @session, "echo logs_test_output", "--json")
    result = drive_json("logs", @session)
    assert result["ok"]
    assert_match(/logs_test_output/, result["content"])
  end

  def test_poll_command_json
    drive("session", "create", @session, "--detach", "--json")
    drive("send", @session, "echo POLL_READY", "--json")
    sleep 0.5
    result = drive_json("poll", @session, "--until", "POLL_READY", "--timeout", "5")
    assert result["ok"]
    assert_match(/POLL_READY/, result["match"])
  end

  def test_fanout_command_json
    s1 = "#{@session}_a"
    s2 = "#{@session}_b"
    drive("session", "create", s1, "--detach", "--json")
    drive("session", "create", s2, "--detach", "--json")

    result = drive_json("fanout", "echo fanout_ok", "--targets", "#{s1},#{s2}")
    assert result["ok"]
    assert_equal 2, result["results"].length

    system("tmux kill-session -t #{s1} 2>/dev/null")
    system("tmux kill-session -t #{s2} 2>/dev/null")
  end

  # Proc commands
  def test_proc_list_json
    result = drive_json("proc", "list")
    assert result["ok"]
    assert result["count"] > 0
    assert result["processes"].is_a?(Array)
  end

  def test_proc_list_filter_by_name
    result = drive_json("proc", "list", "--name", "ruby")
    assert result["ok"]
    assert result["processes"].length > 0
  end

  def test_proc_tree_json
    result = drive_json("proc", "tree", Process.pid.to_s)
    assert result["ok"]
    assert_equal Process.pid, result["tree"]["pid"]
  end

  def test_proc_top_json
    result = drive_json("proc", "top", "--pid", Process.pid.to_s)
    assert result["ok"]
    assert result["snapshot"].is_a?(Array)
  end
end
