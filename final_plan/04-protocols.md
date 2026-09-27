# 04 · Protocols

Four boundaries: Si ↔ Pi RPC (sessions Si starts), Si ↔ Si bridge (every session with the extension), Si ↔ si-adapter (Node), and `si` CLI ↔ Si node.

## 1. Pi RPC (sessions Si starts)

Authoritative references in the local Pi clone (version 0.87.1):
- `/Users/adam2/projects/pair/pi/packages/coding-agent/docs/rpc.md` (framing, lifecycle)
- `/Users/adam2/projects/pair/pi/packages/coding-agent/docs/rpc-commands.md` (commands)
- `/Users/adam2/projects/pair/pi/packages/coding-agent/docs/json.md` (event stream)

### 1.1 Launch

```
<toolchain>/node_modules/.bin/pi --mode rpc \
  --session-dir $SI_HOME/sessions --session-id <ses_id> \
  --provider <provider> --model <model> --thinking <level> \
  --no-extensions -e <fabric path> [-e <fovea path>] -e <repo>/bridge \
  [--tools <the role's allowlist, including its si_* tools>] [--append-system-prompt <prompt file>]... \
  --no-approve
```
Environment: `PI_CODING_AGENT_DIR=$SI_HOME/profiles/<profile>`, `PI_CACHE_RETENTION`, `SI_BRIDGE_URL`, `SI_BRIDGE_TOKEN`, `SI_SESSION_ID`, `SI_ROLE`, `SI_RUN_ID`, `SI_TASK_ID`, and `SI_CACHE_AFFINITY_HEADER` when configured. Working directory: the session's worktree.

- `--session-id` creates the session when it does not exist and reopens it otherwise, so restarting a session is the same command. `--session <path>` only opens existing sessions. The session file path is read from `get_state` (`sessionFile`).
- `--tools` is an allowlist over built-in **and** extension tools, so a restricted role must list its `si_*` tools (and the Lead its Fovea tools).
- In builders, Fabric's full code mode hides extension tools from the model; the builder profile keeps the `si_*` tools visible with `capture.keepVisible`.

### 1.2 Framing (must follow exactly)

- stdin: one JSON object per record, terminated by `\n`.
- stdout: split **only** on byte `0x0A`; strip one trailing `\r`. Never split on U+2028/U+2029.
- Records larger than 64 MiB are skipped: bytes are discarded up to the next newline and the record is counted. The session continues. Si never sends whole-transcript commands (`get_messages`, `get_entries`) in normal operation (Pair F-05).
- A stdout line that is not valid JSON: log it (first 200 bytes) at warning level, increment a counter, continue. Never crash the controller (Pair's F-05/F-06 lesson).
- stderr is diagnostics only: append to `$SI_HOME/logs/sessions/<ses_id>.stderr.log`.

### 1.3 Commands Si uses

Every command carries a unique string `id` (`"r<integer>"`) and Si correlates the `response` record by `id`, never by order.

| Command | When |
|---|---|
| `prompt` `{message}` | Start a turn (first task message; follow-ups when idle). Check `data.disposition`; if `"handled"` do not wait for `agent_settled`. Deadline 15 minutes, extended by compaction events: Pi may compact before answering (Pair F-06). A timeout never stops the session. |
| `steer` `{message}` | Deliver during a turn (fallback when the bridge is disconnected) |
| `follow_up` `{message}` | Queue after the current run |
| `abort` | Stop the current turn |
| `get_state` | Health check at start and in reconcilers |
| `get_session_stats` | Fallback usage totals |
| `set_model` `{provider, modelId}` | Model switch between turns (fallback) |
| `set_thinking_level` `{level}` | Between turns (fallback) |
| `compact` | Manual compaction (deadline 15 minutes) |
| `get_last_assistant_text` | Diagnostics only |

### 1.4 Events Si consumes from RPC

`agent_start`, `agent_end`, `agent_settled`, `turn_start`, `turn_end`, `message_end`, `tool_execution_start`, `tool_execution_end`, `compaction_start` and `compaction_end` (set and clear the controller's `compacting` flag), `auto_retry_*` (names per `json.md`). Unknown event types are ignored. The controller uses them for state only; analytics come from the bridge (richer), with RPC as the fallback when the bridge is not connected.

### 1.5 Shutdown

1. If running: `abort`, wait up to 5 s for `agent_settled`.
2. Close the Port (stdin EOF → Pi disposes its runtime and exits).
3. After 5 s: `SIGTERM` to the OS pid and its descendants; after 5 more seconds: `SIGKILL`.

## 2. Si bridge protocol v1

Transport: Phoenix Channels (protocol `vsn=2.0.0`) over WebSocket at `ws://127.0.0.1:<http.port>/bridge/websocket`. Client library: the `phoenix` npm package. JSON Schemas for every message live in `protocol/bridge/v1/` (task T04.01); both sides validate against them in tests.

### 2.1 Connect and join

- Socket params: `{token}`. `SiWeb.BridgeSocket.connect/3` compares it with `$SI_HOME/bridge_token` using `Plug.Crypto.secure_compare/2`; mismatch → `:error`.
- The endpoint binds `127.0.0.1` only (config `http.ip`).
- Topic: `session:<session_id>` for Si-started sessions (`SI_SESSION_ID`), or `session:new` for your own sessions (Si assigns an id and returns it).

Join payload (`join.schema.json`):
```json
{
  "protocol": 1,
  "session_id": "ses_01j9...",
  "role": "builder",
  "pid": 48213,
  "cwd": "/Users/adam2/.si/worktrees/repo_01.../wt_01...",
  "session_file": "/Users/adam2/.si/sessions/ses_01j9....jsonl",
  "versions": {"pi": "0.87.1", "fabric": "0.97.0", "fovea": "0.31.1", "bridge": "0.1.0"},
  "mode": "control",
  "parent_session_id": null,
  "run_id": null,
  "task_id": "tsk_01j9..."
}
```
Join reply:
```json
{"session_id": "ses_01j9...", "mode": "control", "server_protocol": 1,
 "slot_timeout_ms": 2000, "batch_ms": 100, "max_batch": 50}
```
Join errors: `{"reason": "protocol_unsupported" | "unknown_session" | "invalid_join"}`.

### 2.2 Client → server

| Event | Payload | Reply |
|---|---|---|
| `events` | `{"batch": [Event, ...]}` (≤ `max_batch`) | `{}` |
| `slot_request` | `{"call_id", "provider", "model", "priority", "request_bytes"}` | `{"grant": true, "slot_id"}` (the server may delay the reply) |
| `slot_release` | `{"slot_id", "call_id", "status", "latency_ms", "retry_after_s"}` | `{}` |
| `tool` | `{"name", "call_id", "args"}` | `{"ok": true, "result": {...}}` or `{"ok": false, "error": "..."}` |
| `control_ack` | `{"control_id", "ok", "error", "result"}` | none (push) |

Event envelope: `{"seq": <int, per connection, starts at 1>, "at": "<ISO 8601>", "type": "<type>", "data": {...}}`. The server drops events with `seq ≤` the last stored seq for that connection (at-least-once delivery from the client buffer).

Event types and `data`:

| type | data |
|---|---|
| `session_start` | `session_file`, `model {provider, id}`, `thinking`, `tools [..]` |
| `session_shutdown` | `reason` |
| `agent_start`, `agent_end`, `agent_settled` | `{}` |
| `turn_start` | `turn` |
| `turn_end` | `turn`, `duration_ms`, `tool_calls`, `context {tokens, window}` |
| `message_end` | `role`, `entry_id`, `stop_reason`, `model`, `usage {input, output, cache_read, cache_write, cost}` |
| `model_call` | `call_id`, `provider`, `model`, `request_bytes`, `wait_ms`, `status`, `latency_ms`, `retry_after_s` |
| `tool_start` | `tool_call_id`, `name` |
| `tool_end` | `tool_call_id`, `name`, `duration_ms`, `ok`, `output_bytes`, `files [..]`, `exit_code` |
| `fabric_exec` | `tool_call_id`, `outcome`, `phases [..]`, `operation_count`, `failure {stage, error_class, message}` or null |
| `model_select` | `provider`, `model` |
| `thinking_select` | `level` |
| `compaction` | `reason`, `before_tokens`, `after_tokens` |
| `notice` | `level`, `message` (bridge diagnostics) |
| `mode_changed` | `mode` (your sessions, from T04.12) |

Missing source fields are sent as `null`. Transcript text is never sent; `entry_id` + `session_file` point to it.

### 2.3 Server → client

`control` push: `{"control_id": "ctl_…", "action": "<action>", "args": {...}}`. The client answers with a `control_ack` push.

| action | args | Pi API used by the bridge |
|---|---|---|
| `deliver` | `{"text", "as": "steer" \| "followUp" \| "nextTurn"}` | `pi.sendUserMessage(text, {deliverAs})` (nextTurn: `pi.sendMessage` with `deliverAs: "nextTurn"`) |
| `abort` | `{}` | `ctx.abort()` |
| `set_model` | `{"provider", "model"}` | `ctx.modelRegistry.find` + `pi.setModel(model)` |
| `set_thinking` | `{"level"}` | `pi.setThinkingLevel(level)` |
| `set_tools` | `{"tools": [..]}` | `pi.setActiveTools(names)` |
| `compact` | `{}` | `ctx.compact()` |
| `status` | `{"text"}` | `ctx.ui.setStatus("si", text)` |
| `pause` / `resume` | `{}` | handled inside the bridge's slot gate |

Controls are only executed when the session's mode is `control`; in `suggest` mode only `deliver` with `as: "nextTurn"` is allowed; in `observe` mode every control is rejected with `ok: false, error: "mode_observe"`.

### 2.4 Tools registered by the bridge

Defined as Pi tools with TypeBox parameter schemas equal to `protocol/tools/*.schema.json`. `execute()` sends a `tool` request and returns the server's result as the tool result `content` (short text) and `details` (the JSON). If Si is not connected, the tool throws `Error("Si is not connected")` (a failed tool result the model can see).

| Tool | Registered for roles | Terminates the turn |
|---|---|---|
| `si_task` | builder | no |
| `si_report` | builder; astra in fix mode (from T05.08) | yes (`terminate: true`) |
| `si_ask` | all | no |
| `si_scope` | builder | no |
| `si_verdict` | astra, critic, arbiter | yes |
| `si_plan` | lead | yes |
| `si_dispute` | builder | no |

Role comes from `SI_ROLE`; tools not meant for the role are not registered.

### 2.5 Slot gate

- On `before_provider_request`: if connected, push `slot_request` and await the reply with no client timeout (the server decides). If not connected, or the channel errors, wait at most `slot_timeout_ms` for a connection, then proceed.
- While paused (`pause` control), new requests wait until `resume`. A request held longer than 30 minutes aborts the turn with a notice.
- On `after_provider_response`: push `slot_release` with status, latency and `Retry-After` (seconds) when present.

### 2.6 Versioning

`protocol: 1` in the join. The server accepts protocol versions listed in `Si.Bridge.Protocol.supported/0`. Both sides ignore unknown fields. Breaking changes increment the protocol number.

## 3. si-adapter protocol v1 (from M10)

- Transport: Erlang Port with `{:packet, 4}`: each message is a 4-byte big-endian length followed by UTF-8 JSON. The adapter reads stdin and writes stdout with the same framing, logs to stderr, and exits on stdin EOF.
- Handshake: on start the adapter sends `{"id": 0, "op": "hello", "ok": true, "result": {"adapter": "0.1.0", "fabric": "0.97.0", "fovea": "0.31.1", "node": "v22.x"}}`. `Si.Adapter` refuses to mark itself ready if versions differ from the pinned toolchain.
- Request: `{"id": <int>, "op": "<name>", "args": {...}}`; response: `{"id": <same>, "ok": true, "result": {...}}` or `{"id": <same>, "ok": false, "error": {"code": "...", "message": "..."}}`.
- Ops: `hello`, `fovea.seed_cache {from_root, to_root}`, `fovea.impact {root, files, base}`, `fabric.child_usage {since}`, `fabric.mesh.members {root}`, `fabric.mesh.tail {root, cursor}`, `fabric.mesh.list {root, prefix}`, `shutdown`.
- Timeouts: default 30 s per request (Elixir side); the adapter processes requests concurrently and may answer out of order.

## 4. CLI ↔ node

- The `si` escript (`cli/`) starts a hidden distributed node named `si_cli_<os_pid>` with short names, sets the cookie from `$SI_HOME/cookie`, and calls `:erpc.call(node, Si.CLI.Server, :run, [argv, ctx], :infinity)` where `node` is `SI_NODE` or `:"si@<short hostname>"`.
- `ctx`: `%{cwd: String.t(), caller: pid(), tty: boolean(), columns: integer() | nil}`.
- The server streams output with `send(ctx.caller, {:si_cli, :stdout | :stderr, iodata})` and finishes with `send(ctx.caller, {:si_cli, :exit, code})`; `run/2` returns `:ok` after sending the exit message.
- The escript prints streamed output as it arrives and exits with the code. If the node is unreachable it prints `Si is not running (tried <node>). Start it with bin/si-server.` and exits 69.
- Exit codes: `0` success/approve, `1` revise/failed check/command failure, `2` usage error, `69` node unavailable, `70` internal error.
