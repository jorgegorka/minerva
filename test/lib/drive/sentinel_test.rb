# frozen_string_literal: true

require "minitest/autorun"
require "securerandom"
require_relative "../../../lib/drive/sentinel"

class Drive::SentinelTest < Minitest::Test
  def test_generate_token_is_8_hex_chars
    token = Drive::Sentinel.generate_token
    assert_match(/\A[0-9a-f]{8}\z/, token)
  end

  def test_generate_token_is_unique
    tokens = 10.times.map { Drive::Sentinel.generate_token }
    assert_equal 10, tokens.uniq.length
  end

  def test_wrap_command
    wrapped = Drive::Sentinel.wrap_command("ls -la", "abcd1234")
    assert_equal 'echo "__START_abcd1234" ; ls -la ; echo "__DONE_abcd1234:$?"', wrapped
  end

  def test_detect_completion_found
    token = "abcd1234"
    captured = <<~OUTPUT
      $ echo "__START_abcd1234" ; ls ; echo "__DONE_abcd1234:$?"
      __START_abcd1234
      file1.txt
      file2.txt
      __DONE_abcd1234:0
    OUTPUT
    found, exit_code, output = Drive::Sentinel.detect_completion(captured, token)
    assert found
    assert_equal 0, exit_code
    assert_match(/file1\.txt/, output)
    assert_match(/file2\.txt/, output)
  end

  def test_detect_completion_with_nonzero_exit
    token = "abcd1234"
    captured = "__START_abcd1234\nsome error\n__DONE_abcd1234:1\n"
    found, exit_code, output = Drive::Sentinel.detect_completion(captured, token)
    assert found
    assert_equal 1, exit_code
    assert_match(/some error/, output)
  end

  def test_detect_completion_not_found
    token = "abcd1234"
    captured = "still running...\n"
    found, exit_code, output = Drive::Sentinel.detect_completion(captured, token)
    refute found
    assert_nil exit_code
    assert_equal "", output
  end

  def test_detect_completion_without_start_marker
    token = "abcd1234"
    captured = "previous output\n__DONE_abcd1234:0\n"
    found, exit_code, output = Drive::Sentinel.detect_completion(captured, token)
    assert found
    assert_equal 0, exit_code
    assert_equal "previous output", output
  end
end

class Drive::SentinelIntegrationTest < Minitest::Test
  def setup
    @session = "drive_sentinel_#{$$}_#{SecureRandom.hex(4)}"
    Drive::Tmux.create_session(@session, detach: true)
  end

  def teardown
    system("tmux kill-session -t #{@session} 2>/dev/null")
  end

  def test_run_and_wait_success
    exit_code, output = Drive::Sentinel.run_and_wait(@session, "echo hello_sentinel", timeout: 10.0)
    assert_equal 0, exit_code
    assert_match(/hello_sentinel/, output)
  end

  def test_run_and_wait_nonzero_exit
    exit_code, _output = Drive::Sentinel.run_and_wait(@session, "bash -c 'exit 42'", timeout: 10.0)
    assert_equal 42, exit_code
  end

  def test_run_and_wait_timeout
    assert_raises(Drive::CommandTimeoutError) do
      Drive::Sentinel.run_and_wait(@session, "sleep 60", timeout: 2.0)
    end
  end
end
