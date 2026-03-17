require "test_helper"
require "minitest/mock"

class ConsolesControllerTest < ActionDispatch::IntegrationTest
  FAKE_SESSION = Drive::Tmux::SessionInfo.new(
    name: "test-session", windows: 2, created: "Thu Mar 13 10:00:00 2026", attached: false
  )

  FAKE_PROCESS = Drive::ProcessManager::ProcessInfo.new(
    uid: 501, pid: 1234, ppid: 100, name: "ruby", command: "ruby app.rb",
    cpu: 2.5, memory_mb: 64.0, elapsed: "5m30s", state: "S+", cwd: "/tmp", session: "test-session"
  )

  test "index returns 200 and renders session list" do
    Drive::Tmux.stub(:list_sessions, [ FAKE_SESSION ]) do
      Drive::Tmux.stub(:capture_pane, "user@host:~$ ") do
        get consoles_url
        assert_response :success
        assert_select "h3", "test-session"
      end
    end
  end

  test "index as JSON returns array" do
    Drive::Tmux.stub(:list_sessions, [ FAKE_SESSION ]) do
      Drive::Tmux.stub(:capture_pane, "user@host:~$ ") do
        get consoles_url(format: :json)
        assert_response :success
        data = JSON.parse(response.body)
        assert_kind_of Array, data
        assert_equal "test-session", data.first["name"]
      end
    end
  end

  test "index with no sessions shows empty state" do
    Drive::Tmux.stub(:list_sessions, []) do
      get consoles_url
      assert_response :success
      assert_select "p", /No active tmux sessions/
    end
  end

  test "show returns 200 with terminal preview" do
    Drive::Tmux.stub(:require_session, nil) do
      Drive::Tmux.stub(:list_sessions, [ FAKE_SESSION ]) do
        Drive::Tmux.stub(:capture_pane, "$ echo hello\nhello\n$ ") do
          Drive::ProcessManager.stub(:list_processes, [ FAKE_PROCESS ]) do
            get console_url(name: "test-session")
            assert_response :success
            assert_select "h1", "test-session"
            assert_select ".console-terminal__output"
          end
        end
      end
    end
  end

  test "show as JSON returns console data" do
    Drive::Tmux.stub(:require_session, nil) do
      Drive::Tmux.stub(:list_sessions, [ FAKE_SESSION ]) do
        Drive::Tmux.stub(:capture_pane, "$ echo hello\nhello\n$ ") do
          Drive::ProcessManager.stub(:list_processes, [ FAKE_PROCESS ]) do
            get console_url(name: "test-session", format: :json)
            assert_response :success
            data = JSON.parse(response.body)
            assert_equal "test-session", data["console"]["name"]
            assert_kind_of Array, data["processes"]
          end
        end
      end
    end
  end

  test "destroy kills session and redirects" do
    killed = false
    kill_stub = ->(_name) { killed = true }

    Drive::Tmux.stub(:kill_session, kill_stub) do
      delete console_url(name: "test-session")
      assert killed
      assert_redirected_to consoles_url
      follow_redirect!
      assert_select ".alert", /terminated/
    end
  end

  test "send_keys sends command and redirects" do
    sent_keys = nil
    send_stub = ->(session, keys, literal:) { sent_keys = keys }

    Drive::Tmux.stub(:send_keys, send_stub) do
      post send_keys_console_url(name: "test-session"), params: { text: "ls -la" }
      assert_equal "ls -la", sent_keys
      assert_redirected_to console_url(name: "test-session")
    end
  end

  test "handles TmuxNotFoundError with 503" do
    error_stub = -> { raise Drive::TmuxNotFoundError }

    Drive::Tmux.stub(:list_sessions, error_stub) do
      get consoles_url
      assert_response :service_unavailable
      assert_select "p", /tmux is not installed/
    end
  end

  test "handles TmuxNotFoundError as JSON with 503" do
    error_stub = -> { raise Drive::TmuxNotFoundError }

    Drive::Tmux.stub(:list_sessions, error_stub) do
      get consoles_url(format: :json)
      assert_response :service_unavailable
      data = JSON.parse(response.body)
      assert_equal "tmux not found", data["error"]
    end
  end

  test "handles SessionNotFoundError with redirect" do
    error_stub = ->(_name) { raise Drive::SessionNotFoundError.new("ghost") }

    Drive::Tmux.stub(:require_session, error_stub) do
      get console_url(name: "ghost")
      assert_redirected_to consoles_url
      follow_redirect!

      Drive::Tmux.stub(:list_sessions, []) do
        assert_select ".alert", /Session not found/
      end
    end
  end
end
