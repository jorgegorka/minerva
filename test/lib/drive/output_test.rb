# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "../../../lib/drive/output"

class Drive::OutputTest < Minitest::Test
  def test_emit_json_mode
    output = capture_io do
      Drive::Output.emit({ ok: true, data: "hello" }, json: true, human_lines: "Hello")
    end.first
    parsed = JSON.parse(output.strip)
    assert_equal true, parsed["ok"]
    assert_equal "hello", parsed["data"]
  end

  def test_emit_human_mode_string
    output = capture_io do
      Drive::Output.emit({ ok: true }, json: false, human_lines: "Hello world")
    end.first
    assert_equal "Hello world\n", output
  end

  def test_emit_human_mode_array
    output = capture_io do
      Drive::Output.emit({ ok: true }, json: false, human_lines: ["Line 1", "Line 2"])
    end.first
    assert_equal "Line 1\nLine 2\n", output
  end

  def test_emit_error_json_mode
    error = Drive::DriveError.new("boom")
    out, _err = capture_io do
      assert_raises(SystemExit) { Drive::Output.emit_error(error, json: true) }
    end
    parsed = JSON.parse(out.strip)
    assert_equal false, parsed["ok"]
    assert_equal "boom", parsed["message"]
  end

  def test_emit_error_human_mode
    error = Drive::DriveError.new("boom")
    _out, err = capture_io do
      assert_raises(SystemExit) { Drive::Output.emit_error(error, json: false) }
    end
    assert_match(/boom/, err)
  end
end
