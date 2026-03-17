# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/drive/prompt_detector"

class Drive::PromptDetectorTest < Minitest::Test
  def test_detect_nil_returns_unknown
    assert_equal :unknown, Drive::PromptDetector.detect(nil)
  end

  def test_detect_empty_string_returns_unknown
    assert_equal :unknown, Drive::PromptDetector.detect("")
    assert_equal :unknown, Drive::PromptDetector.detect("   \n  ")
  end

  def test_detect_waiting_for_input_y_n
    output = "Proceed with installation? [y/N]"
    assert_equal :waiting_for_input, Drive::PromptDetector.detect(output)
  end

  def test_detect_waiting_for_input_password
    output = "some output\nPassword: "
    assert_equal :waiting_for_input, Drive::PromptDetector.detect(output)
  end

  def test_detect_waiting_for_input_are_you_sure
    output = "Are you sure you want to continue?"
    assert_equal :waiting_for_input, Drive::PromptDetector.detect(output)
  end

  def test_detect_waiting_for_input_overwrite
    output = "File exists. Overwrite?"
    assert_equal :waiting_for_input, Drive::PromptDetector.detect(output)
  end

  def test_detect_error_fatal
    output = "fatal: not a git repository"
    assert_equal :error, Drive::PromptDetector.detect(output)
  end

  def test_detect_error_traceback
    output = "Traceback (most recent call last):\n  File \"test.py\", line 1"
    assert_equal :error, Drive::PromptDetector.detect(output)
  end

  def test_detect_error_command_not_found
    output = "bash: foo: command not found"
    assert_equal :error, Drive::PromptDetector.detect(output)
  end

  def test_detect_error_permission_denied
    output = "Permission denied (publickey)."
    assert_equal :error, Drive::PromptDetector.detect(output)
  end

  def test_detect_idle_shell_prompt_dollar
    output = "user@host:~$ "
    assert_equal :idle, Drive::PromptDetector.detect(output)
  end

  def test_detect_idle_shell_prompt_hash
    output = "root@host:~# "
    assert_equal :idle, Drive::PromptDetector.detect(output)
  end

  def test_detect_idle_irb_prompt
    output = "irb(main):001:0> "
    assert_equal :idle, Drive::PromptDetector.detect(output)
  end

  def test_detect_idle_pry_prompt
    output = "pry(main)> "
    assert_equal :idle, Drive::PromptDetector.detect(output)
  end

  def test_detect_idle_python_prompt
    output = ">>> "
    assert_equal :idle, Drive::PromptDetector.detect(output)
  end

  def test_detect_active_running_process
    output = "Compiling assets...\nProcessing file 42 of 100"
    assert_equal :active, Drive::PromptDetector.detect(output)
  end

  def test_status_label
    assert_equal "Running", Drive::PromptDetector.status_label(:active)
    assert_equal "Waiting", Drive::PromptDetector.status_label(:waiting_for_input)
    assert_equal "Idle", Drive::PromptDetector.status_label(:idle)
    assert_equal "Error", Drive::PromptDetector.status_label(:error)
    assert_equal "Unknown", Drive::PromptDetector.status_label(:unknown)
  end

  def test_status_css_class
    assert_equal "console-status--active", Drive::PromptDetector.status_css_class(:active)
    assert_equal "console-status--waiting", Drive::PromptDetector.status_css_class(:waiting_for_input)
    assert_equal "console-status--idle", Drive::PromptDetector.status_css_class(:idle)
    assert_equal "console-status--error", Drive::PromptDetector.status_css_class(:error)
    assert_equal "console-status--unknown", Drive::PromptDetector.status_css_class(:unknown)
  end
end
