# Drive CLI — Terminal Automation via tmux (Ruby)

## Summary

A standalone Ruby CLI tool that provides programmatic control over tmux sessions for AI agents. Converted from the Python `drive-cli` tool. Uses Thor for subcommand routing, shells out to `tmux`/`ps`/`kill` for system interaction, and supports dual JSON/human-readable output.

**Invocation:** `bin/drive <command> [subcommand] [args] [--json]`

**No Rails dependency.** Pure Ruby + Thor + stdlib. Fast startup, no Rails boot.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI framework | Thor | Rich subcommand support, widely used in Ruby ecosystem |
| Process management | Shell out to `ps`/`kill` | Zero extra gems, works on macOS (dev) and Linux (prod) |
| Code location | `lib/drive/` | Standalone tool, not a Rails service object |
| Module pattern | `Drive::` namespace, module methods | No Callable pattern — this isn't a Rails middleware |
| Subprocess calls | `Open3.capture3` | Returns stdout, stderr, and exit status cleanly |
| Parallelism (fanout) | Ruby `Thread` pool | Simple, no gem needed, sufficient for I/O-bound tmux calls |
| Token generation | `SecureRandom.hex(4)` | 8-char hex token, replaces Python's `uuid4().hex[:8]` |
| JSON output | `--json` flag on every command | Structured output for agent parsing |

## File Structure

```
bin/drive                      # Executable entry point
lib/drive/
  cli.rb                      # Thor CLI: registers all subcommands
  tmux.rb                     # Subprocess wrappers for tmux binary
  sentinel.rb                 # Sentinel protocol (wrap/detect/extract)
  process_manager.rb          # Shell out to ps/kill for process ops
  errors.rb                   # Error hierarchy (DriveError base class)
  output.rb                   # emit/emit_error for JSON/human output
.claude/skills/drive/
  SKILL.md                    # Reference skill for Claude agents
```

## Commands

### session (subcommand group)

| Subcommand | Signature | Description |
|------------|-----------|-------------|
| `create` | `bin/drive session create NAME [--window NAME] [--dir PATH] [--detach] [--json]` | Create tmux session. Headed by default (opens Terminal.app on macOS). `--detach` for headless. On Linux, always detached. |
| `list` | `bin/drive session list [--json]` | List all tmux sessions |
| `kill` | `bin/drive session kill NAME [--json]` | Kill a tmux session |

### run

```
bin/drive run SESSION CMD [--timeout 30] [--pane INDEX] [--json]
```

Execute a command and wait for completion using sentinel protocol. Returns exit code and captured output.

**Note:** `run` is a Thor reserved word. The Ruby method is named `run_command` and mapped via `map "run" => :run_command`.

### send

```
bin/drive send SESSION TEXT [--pane INDEX] [--enter/--no-enter] [--json]
```

Send raw keystrokes. No completion waiting. For interactive tools (vim, ipython). Default: `--enter` (appends Enter key).

### logs

```
bin/drive logs SESSION [--pane INDEX] [--lines N] [--json]
```

Capture pane content. `--lines N` captures the last N lines of scrollback history (maps to `capture_pane -S -N`). Without `--lines`, captures the visible pane content only.

### poll

```
bin/drive poll SESSION --until PATTERN [--timeout 30] [--interval 0.5] [--pane INDEX] [--json]
```

Wait for regex pattern match in pane output. Returns matched text and full content.

### fanout

```
bin/drive fanout CMD --targets SESSION1,SESSION2,... [--timeout 30] [--json]
```

Run command in parallel across multiple sessions using threads. Always waits for all threads to complete. Returns per-session results with individual success/failure status, ordered by original target order. Overall `ok` is true only if all sessions succeeded.

### proc (subcommand group)

| Subcommand | Signature | Description |
|------------|-----------|-------------|
| `list` | `bin/drive proc list [--name NAME] [--session NAME] [--parent PID] [--cwd PATH] [--json]` | List user processes with filters |
| `kill` | `bin/drive proc kill [PID] [--name NAME] [--signal 15] [--force] [--tree] [--json]` | Kill by PID (positional) or by name (`--name`). One or the other required, not both. Two-step: SIGTERM → wait 5s → SIGKILL |
| `tree` | `bin/drive proc tree PID [--session NAME] [--json]` | Show process tree from PID |
| `top` | `bin/drive proc top [--pid PID1,PID2] [--session NAME] [--json]` | Resource snapshot (CPU, memory) |

## Module Design

### Drive::Tmux (`lib/drive/tmux.rb`)

Module with class-level methods for all tmux interaction.

**Key methods:**
- `require_tmux` — find tmux binary or raise `TmuxNotFoundError`
- `run(args, check: true)` — centralized subprocess wrapper using `Process.spawn` + `IO.select` for reliable 10s timeout (avoids `Timeout.timeout` pitfalls)
- `session_exists?(name)` / `require_session(name)` — session validation
- `create_session(name, window_name:, start_directory:, detach:)` — on macOS headed mode uses `osascript` to open Terminal.app; if `osascript` fails (e.g. SSH session, no GUI), falls back to detached mode. On Linux, always detached.
- `list_sessions` — parse `tmux list-sessions -F` output into `SessionInfo` structs
- `kill_session(name)` — kill by name
- `send_keys(session, keys, pane:, enter:, literal:)` — send keystrokes; when literal, sends Enter as separate non-literal key press
- `capture_pane(session, pane:, start_line:, end_line:)` — capture pane content with optional scrollback

**Data:** `SessionInfo = Data.define(:name, :windows, :created, :attached)`

### Drive::Sentinel (`lib/drive/sentinel.rb`)

Module implementing the sentinel protocol for reliable command completion detection.

**Protocol:**
1. Generate 8-char hex token via `SecureRandom.hex(4)`
2. Wrap command: `echo "__START_<T>" ; <cmd> ; echo "__DONE_<T>:$?"`
3. Send wrapped command to tmux pane
4. Poll `capture_pane` at 0.2s intervals
5. Extract output between `__START_` and `__DONE_` markers, parse exit code

**Key methods:**
- `generate_token` — `SecureRandom.hex(4)`
- `wrap_command(cmd, token)` — wrap with start/done sentinels
- `detect_completion(captured, token)` — returns `[found, exit_code, output]`
- `run_and_wait(session, cmd, pane:, timeout:, poll_interval:)` — full execution cycle

### Drive::ProcessManager (`lib/drive/process_manager.rb`)

Module for process management via `ps` and `kill` system commands.

**`ps` command:** `ps -eo pid,ppid,pcpu,rss,etime,stat,command` — works on both macOS and Linux.

**Key methods:**
- `list_processes(name:, parent:, session:, cwd:)` — parse `ps` output, filter by ppid/name/cwd in Ruby, return `ProcessInfo` structs
- `kill_process(pid:, name:, signal:, tree:)` — two-step kill pattern: `Process.kill(signal, pid)` then poll with `Process.kill(0, pid)` to detect death (avoids `Process.wait2` which only works for child processes). Falls back to SIGKILL after 5s.
- `process_tree(pid)` — fetch all processes via `ps -eo pid,ppid,...`, build tree in Ruby by filtering on ppid (no `ps --ppid` which is unavailable on macOS)
- `process_snapshot(pids)` — resource snapshot for specific PIDs
- `session_pid_map` — map tmux pane PIDs to session names via `tmux list-panes`

**CWD resolution:** `ps` does not provide cwd. On Linux, read `/proc/PID/cwd` symlink. On macOS, use `lsof -a -d cwd -Fn -p PID`. Falls back to empty string if unavailable.

**Data:** `ProcessInfo = Data.define(:pid, :ppid, :name, :command, :cpu, :memory_mb, :elapsed, :state, :cwd, :session)`

### Drive::Errors (`lib/drive/errors.rb`)

```
DriveError (base, has #code and #to_h)
  ├── TmuxNotFoundError       (code: "tmux_not_found")
  ├── SessionNotFoundError    (code: "session_not_found")
  ├── SessionExistsError      (code: "session_exists")
  ├── CommandTimeoutError     (code: "timeout")
  ├── TmuxCommandError        (code: "tmux_error")
  ├── PatternNotFoundError    (code: "pattern_not_found")
  ├── ProcessNotFoundError    (code: "process_not_found")
  └── KillPermissionError     (code: "kill_permission_denied")
```

All errors inherit from `DriveError < StandardError`. Each has a `#code` method returning a string identifier and `#to_h` returning `{ ok: false, error: code, message: message }`.

### Drive::Output (`lib/drive/output.rb`)

**Methods:**
- `emit(data, json:, human_lines:)` — if `json:`, prints `data.to_json`; otherwise prints `human_lines`
- `emit_error(err, json:)` — if `json:`, prints `err.to_h.to_json`; otherwise prints `"Error: #{err.message}"` to stderr. Exits with code 1.

### Drive::Cli (`lib/drive/cli.rb`)

Thor CLI class. Registers `session` and `proc` as subcommand groups, and `run`, `send`, `logs`, `poll`, `fanout` as top-level commands. Uses `map "run" => :run_command` to avoid Thor's reserved word conflict.

Each command method:
1. Calls the appropriate module method
2. Wraps in begin/rescue for `DriveError`
3. Uses `Drive::Output.emit` or `Drive::Output.emit_error`

## Entry Point

`bin/drive`:
```ruby
#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "drive/cli"
Drive::Cli.start(ARGV)
```

## Platform Handling

- **macOS (dev):** `session create` opens Terminal.app window via `osascript` by default. `--detach` for headless.
- **Linux (prod):** `session create` always creates detached sessions (no `osascript`). Platform detected via `RUBY_PLATFORM`.

## Testing

**Framework:** Minitest (project standard). No Rails boot.

**Location:** `test/lib/drive/`

**Unit tests (no tmux needed):**
- `test/lib/drive/sentinel_test.rb` — `wrap_command`, `detect_completion`, token extraction
- `test/lib/drive/process_manager_test.rb` — `ps` output parsing with mocked `Open3` calls
- `test/lib/drive/output_test.rb` — JSON vs human output modes
- `test/lib/drive/errors_test.rb` — `#code` and `#to_h` for each error type

**Integration tests (require tmux):**
- `test/lib/drive/tmux_test.rb` — create/list/kill sessions, send keys, capture pane
- `test/lib/drive/cli_test.rb` — end-to-end via `Open3.capture3("bin/drive ...")`

## Dependencies

**New gem:** `thor` (add to Gemfile)

**Stdlib only:** `open3`, `json`, `securerandom`, `shellwords`

## Skill

After implementation, create `.claude/skills/drive/SKILL.md` — a reference skill documenting all commands, key patterns, and sentinel protocol. Adapted from the original Python skill with Ruby-specific invocation paths.
