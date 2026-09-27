# 03 · Data model

SQLite via `ecto_sqlite3`. One database file (`$SI_HOME/si.db`). Tables are created by the task that first needs them (one migration per task). Column types below use Ecto types; JSON columns are `:map` or `{:array, :string}` stored as TEXT.

## 1. IDs

`Si.Id.generate(prefix)` returns `"<prefix>_<ULID>"`: a 26-character Crockford base32 ULID (48-bit millisecond timestamp + 80 random bits), lowercase. IDs sort by creation time.

| Prefix | Entity | Prefix | Entity |
|---|---|---|---|
| `evt` | event | `rth` | review thread |
| `repo` | repository | `rev` | review (one round) |
| `wt` | worktree | `fnd` | finding |
| `snp` | snapshot | `apr` | approval |
| `cks` | check slot | `inb` | inbox item |
| `chk` | check result | `tsk` | task |
| `tc` | toolchain | `att` | attempt |
| `ses` | session | `scp` | scope request |
| `mc` | model call | `mq` | merge item |
| `trn` | turn | `dlv` | delivery |
| `tcl` | tool call | `run` | run |
| `fx` | fabric exec | `stp` | run step |
| `ctl` | control message | `plr` | plan revision |
| `slot` | scheduler slot | `sig` | signal |
| `int` | intervention | `lda` | Lead activation |
| `flr` | failure | `les` | lesson |
| `etk` | eval task | `evr` | eval run |
| `evx` | eval result | `can` | canary |

All tables use `id :string` primary keys with these prefixes, `inserted_at`/`updated_at` as `:utc_datetime_usec`, and foreign keys with `on_delete: :restrict` unless stated.

## 2. Tables

### Platform (M00)

**events** (append-only; never updated or deleted)

| Column | Type | Notes |
|---|---|---|
| seq | integer, autoincrement PK | global order |
| id | string, unique | `evt_…` |
| stream | string | `session:<id>`, `task:<id>`, `run:<id>`, `review:<id>`, `repo:<id>`, `system` |
| type | string | see catalog §4 |
| data | map | payload |
| run_id, task_id, session_id | string, nullable | correlation, indexed |
| schema_version | integer | default 1 |
| occurred_at | utc_datetime_usec | |

Indexes: `(stream, seq)`, `(type, seq)`, `(run_id)`, `(task_id)`, `(session_id)`.

### Git and repos (M01)

**repos**: `id`, `path` (unique, canonical absolute), `name`, `default_branch`, `integration_branch` (default `si/integration`), `profile_hash` (sha256 of `.si/repo.yml`, nullable), `profile_confirmed_at` (nullable).

**worktrees**: `id`, `repo_id`, `path` (unique), `purpose` (`worker`, `astra`, `check`, `queue`, `eval`, `warm`), `ref` (nullable branch name), `base_sha`, `status` (`creating`, `ready`, `leased`, `removing`, `removed`, `broken`), `owner` (nullable: session/review/slot id), `removed_at`.

**snapshots**: `id`, `repo_id`, `worktree_id` (nullable), `base_sha`, `tree_sha`, `commit_sha`, `source` (`worktree`, `ref`), `task_id` (nullable), `attempt_id` (nullable), `details` (map: `excluded` paths such as sockets or oversized untracked files). Index `(repo_id, tree_sha)`. Each snapshot commit is protected by the ref `refs/si/snapshots/<id>`.

**check_slots**: `id` (`cks_`), `repo_id`, `index` (0-based), `worktree_id`, `status` (`idle`, `leased`, `broken`), `lease_owner`, `partition` (integer, = index + 1), `port_base` (integer), `leased_at`. Unique `(repo_id, index)`.

### Checks (M02)

**check_results**: `id` (`chk_`), `snapshot_id`, `check` (`format`, `build`, `lint`, `tests`, `diff_coverage`, `mutation`, `test_integrity`, `scope`), `status` (`pass`, `fail`, `skipped`, `error`, `timeout`), `command` (nullable), `exit_code` (nullable), `duration_ms`, `log_path` (nullable), `details` (map: e.g. `%{"coverage" => 83.3}`, integrity findings). Index `(snapshot_id, check)`.

### Sessions (M03–M04)

**toolchains**: `id` (`tc_`), `pi_version`, `fabric_version`, `fovea_version`, `path`, `status` (`installing`, `ready`, `failed`), `error` (nullable). Unique `(pi_version, fabric_version, fovea_version)`.

**sessions**

| Column | Type | Notes |
|---|---|---|
| id | string | `ses_…` |
| kind | string | `si` (started by Si), `user` (your terminal), `fabric_child` |
| role | string | `builder`, `astra`, `lead`, `critic`, `arbiter`, `user`, `eval_single` |
| repo_id, worktree_id, toolchain_id | string, nullable | |
| profile | string, nullable | profile name |
| provider, model, thinking | string | current model |
| cwd | string | |
| session_file | string, nullable | Pi session file path, read from `get_state` (`sessionFile`) when the session is ready |
| os_pid | integer, nullable | |
| state | string | see §3.1 |
| bridge_status | string | `disconnected`, `connected` |
| mode | string | `control`, `suggest`, `observe` |
| parent_session_id, run_id, task_id, review_thread_id | string, nullable | |
| versions | map | Pi, Fabric, Fovea, bridge versions |
| started_at, stopped_at, last_event_at | utc_datetime_usec, nullable | |

**model_calls**: `id` (`mc_`), `session_id`, `call_id`, `provider`, `model`, `request_bytes`, `wait_ms`, `status` (HTTP status or 0 for transport error), `latency_ms`, `retry_after_s` (nullable), `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, `cost_usd` (float, nullable), `gpu_seconds` (float, nullable), `via` (`direct`, `fabric_child`), `started_at`.

**turns**: `id` (`trn_`), `session_id`, `n`, `started_at`, `ended_at`, `duration_ms`, `tool_calls`, `context_tokens`, `context_window`.

**tool_calls**: `id` (`tcl_`), `session_id`, `tool_call_id`, `name`, `started_at`, `duration_ms`, `ok`, `output_bytes`, `files` (list), `exit_code` (nullable).

**fabric_execs**: `id` (`fx_`), `session_id`, `tool_call_id`, `outcome` (`succeeded`, `failed`, `aborted`, `timed_out`), `phases` (list), `operation_count`, `failure_stage` (nullable), `error_class` (nullable), `error_message` (nullable), `fingerprint` (nullable), `at`.

### Review (M05)

**review_threads**: `id` (`rth_`), `repo_id`, `subject_kind` (`task`, `ref`, `worktree`, `plan` (T09.05), `canary` (T12.05)), `task_id` (nullable), `title`, `description` (text), `base_ref`, `head_ref` (nullable), `writer_model` (nullable), `reviewer_model`, `astra_session_id` (nullable), `astra_worktree_id` (nullable), `fix_policy` (`writer`, `astra`, `auto`), `max_rounds`, `round`, `status` (`open`, `approved`, `escalated`, `closed`, `error`).

**reviews**: `id` (`rev_`), `thread_id`, `snapshot_id`, `round`, `purpose` (`review`, `fix_review`, `acceptance`, `final`, `canary`, `plan`), `reviewer_session_id`, `reviewer_model`, `reviewer_family`, `writer_model` (nullable), `writer_family` (nullable), `diversity_level` (`other_family`, `same_family`, `same_model_fresh`), `verdict` (`approve`, `revise`, nullable), `summary`, `prompt_version`, `status` (`running`, `recorded`, `timeout`, `error`), `started_at`, `finished_at`.

**findings**: `id` (`fnd_`), `review_id`, `thread_id`, `severity` (`blocking`, `note`), `downgraded` (boolean: submitted as blocking without evidence), `file`, `line` (nullable), `category`, `problem`, `evidence_kind` (nullable: `failing_test`, `reproduction`, `rule`, `input`), `evidence_detail` (nullable), `suggested_fix` (nullable), `fingerprint`, `status` (`open`, `fixed`, `unfixed`, `disputed`, `dismissed`), `resolved_in_review_id` (nullable).

**approvals**: `id` (`apr_`), `snapshot_id`, `kind` (`review`, `you`, `plan`, `delivery`), `actor`, `review_id` (nullable). Unique `(snapshot_id, kind)`.

**inbox_items**: `id` (`inb_`), `kind` (`escalation`, `approval`, `question`, `dispute`, `budget`, `scope`, `plan_gate`, `external_push`, `integrity_override`), `title`, `body` (markdown), `ref_kind`, `ref_id`, `recommended` (map: `%{"action" => ..., "text" => ...}`), `options` (list of action names), `status` (`open`, `resolved`, `expired`), `resolution` (map, nullable), `wait_policy` (`wait`, `pause`, `default_after`), `default_after_s` (nullable), `resolved_at`.

### Tasks and delivery (M06)

**tasks**: `id` (`tsk_`), `run_id` (nullable), `repo_id`, `key` (nullable plan step id), `title`, `description`, `acceptance` (list), `scope` (list of globs), `approved_scope` (list of files from approved scope requests, T09.06), `test_paths` (list), `depends_on` (list of task ids), `feedback` (text, the last round's feedback), `tier`, `priority` (integer, lower is sooner), `status` (§3.2), `round`, `attempt_count`, `assigned_session_id`, `worktree_id`, `snapshot_id` (latest), `review_thread_id`, `delivery` (map), `lock_version` (integer, optimistic lock).

**attempts**: `id` (`att_`), `task_id`, `session_id`, `n`, `status` (`running`, `reported`, `interrupted`, `abandoned`), `report` (map, nullable), `report_round` (the task round the latest report belongs to; reports are latched once per round), `reported_at`, `started_at`, `ended_at`.

**scope_requests**: `id` (`scp_`), `task_id`, `session_id`, `files` (list), `reason`, `decision` (`pending`, `approved`, `refused`), `decided_by`, `decided_at`.

**merge_items**: `id` (`mq_`), `repo_id`, `task_id`, `snapshot_id`, `status` (`queued`, `testing`, `landed`, `ejected`, `cancelled`), `position`, `batch_id` (nullable), `attempt`, `base_sha` (nullable), `landed_sha` (nullable), `error` (map, nullable).

**deliveries**: `id` (`dlv_`), `task_id` (nullable), `run_id` (nullable), `target` (`branch`, `pr`, `patch`, `merge_local`), `ref` (branch, URL or path), `status` (`pending_approval`, `done`, `failed`), `approval_id` (nullable), `error` (nullable).

### Later milestones

- **M07 evals**: `eval_tasks` (`etk_`: `suite`, `name`, `repo_path`, `base_commit`, `instructions`, `hidden_tests_patch`, `test_command`, `timeout_s`), `eval_runs` (`evr_`: `suite`, `arms`, `repeats`, `status`, `targets`, `report_path`), `eval_results` (`evx_`: `run_id`, `task_id`, `arm`, `repeat`, `passed`, `cost_usd`, `duration_ms`, `interventions`, `review_rounds`, `error`).
- **M09 workflows**: `workflows` (`hash` PK: sha256 hex of canonical JSON, `name`, `source`, `extends`, `origin` (`builtin`, `repo`, `user`, `agent`), `approved`, `approved_by`), `runs` (`run_`: `workflow_hash`, `repo_id`, `goal`, `tier`, `status`, `acceptance`, `budget`, `versions`, `plan_revision`, `finished_at`), `run_steps` (`stp_`), `plan_revisions` (`plr_`: `run_id`, `n`, `graph`, `critique`, `gate`, `status`, `changes`).
- **M12 signals**: `signals` (`sig_`), `interventions` (`int_`), `lead_activations` (`lda_`), `canaries` (`can_`).
- **M13 models**: `model_stats` (`model`, `role`, `window`, `metrics`, `computed_at`; composite PK).
- **M14 learning**: `failures` (`flr_`), `lessons` (`les_`).
- **M11 retention**: `analytics_daily` (day, model, role, provider: calls, tokens by kind, cost, errors) keeps aggregates of pruned analytics rows.

Exact columns for these are specified in their tasks.

## 3. State machines

Transitions not listed are rejected with `{:error, {:invalid_transition, from, to}}`. Every transition writes an event.

### 3.1 Session

```
starting  → idle | stopped | lost
idle      → running | parked | stopping | lost
running   → settling | idle | stopping | lost
settling  → idle | running | stopping | lost
parked    → starting | stopped
stopping  → stopped | lost
```
- `running` on `agent_start`; `settling` on `agent_end`; `idle` on `agent_settled` (from RPC events or the bridge, whichever arrives first; duplicates are ignored).
- `lost` when the OS process exits without Si asking it to.
- Orthogonal to the state, the controller keeps a `compacting` flag (set by `compaction_start`, cleared by `compaction_end`); nothing is delivered while it is set.

### 3.2 Task

```
pending     → ready                       (all depends_on landed)
ready       → assigned | cancelled
assigned    → running | ready             (session failed to start → back to ready)
running     → frozen | blocked | interrupted | cancelled
frozen      → in_review | running         (checks failed → next round)
in_review   → approved | running | escalated   (revise → writer fixes; Astra fixes stay inside in_review)
approved    → queued
queued      → landed | running            (ejected: conflict or failed checks)
blocked     → ready | cancelled
interrupted → ready | escalated
escalated   → ready | cancelled | approved   (your decision)
landed, cancelled, failed: terminal
any non-terminal → failed                 (unrecoverable error, with reason)
```

### 3.3 Review thread and review

- Thread: `open → approved | escalated | closed | error`. `round` increments when a new snapshot is reviewed.
- Review: `running → recorded | timeout | error`.
- Finding: `open → fixed | unfixed | disputed | dismissed`; `unfixed` findings stay open for the next round.

### 3.4 Merge item

`queued → testing → landed | ejected`; `queued → cancelled`.

### 3.5 Run (M09)

`created → planning → plan_gate → executing → accepting → delivering → done`; any → `failed | cancelled | interrupted`.

### 3.6 Inbox item

`open → resolved | expired`.

## 4. Event catalog

Event types are dotted, past tense. `data` keys listed are required; extra keys are allowed.

| Type | Stream | data |
|---|---|---|
| `repo.added` | repo | path, default_branch |
| `repo.profile_confirmed` | repo | profile_hash |
| `worktree.created` / `worktree.removed` | repo | worktree_id, path, purpose |
| `snapshot.frozen` | repo | snapshot_id, tree_sha, commit_sha, base_sha |
| `check.finished` | repo | snapshot_id, check, status, duration_ms |
| `checks.finished` | repo | snapshot_id, status, failed_check |
| `toolchain.ready` | system | toolchain_id, versions |
| `session.started` | session | role, model, cwd |
| `session.state_changed` | session | from, to |
| `session.stopped` / `session.lost` | session | reason, exit_status |
| `bridge.connected` / `bridge.disconnected` | session | versions / reason |
| `control.sent` / `control.acked` | session | control_id, action, ok |
| `review.started` | review | review_id, thread_id, round, reviewer_model |
| `review.recorded` | review | review_id, verdict, blocking, notes |
| `review.thread_closed` | review | thread_id, status |
| `review.escalated` | review | thread_id, reason |
| `finding.status_changed` | review | finding_id, from, to |
| `inbox.created` / `inbox.resolved` | system | item_id, kind / resolution |
| `task.created` | task | title, repo_id |
| `task.transitioned` | task | from, to, reason |
| `attempt.started` / `attempt.reported` / `attempt.interrupted` | task | attempt_id, session_id, report |
| `scope.requested` / `scope.decided` | task | request_id, files, decision |
| `merge.queued` / `merge.landed` / `merge.ejected` | repo | item_id, task_id, landed_sha / reason |
| `delivery.created` | task | delivery_id, target, ref |
| `budget.warned` / `budget.stopped` | run | scope, spent_usd, cap_usd |
| `scheduler.pool_adjusted` | system | pool, from, to, reason |
| `run.*`, `plan.*` | run | defined in M09 tasks |
| `signal.raised`, `intervention.applied`, `lead.decided` | task/run | defined in M12 tasks |
| `reconciler.repaired` | system | reconciler, op_id, action |

Tasks add these types as they need them (each task names them): `tool.called`, `session.ui_request`, `session.large`, `system.frozen`, `model.fallback`, `model.code_mode_changed`, `merge.external_change`, `run.step_changed`, `run.tier_raised`, `toolchain.ready`. Add every new type to this table in the same task.

## 5. What is stored where

| Data | Location |
|---|---|
| Transcripts | Pi session files (`$SI_HOME/sessions/*.jsonl`); Si stores pointers (file + entry id) |
| Check logs | `$SI_HOME/logs/checks/<snp_id>/<check>.log` (tail capped at 2 MiB per check) |
| Session stderr | `$SI_HOME/logs/sessions/<ses_id>.stderr.log` |
| Everything else | SQLite |
