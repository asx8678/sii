# 09 · Pair audit coverage

Your read-only audit of pi-fabric-pair (`/Users/adam2/projects/pair/todo1/13-findings-register.md`) lists 39 findings. This table shows where the plan handles each one, or why it does not apply to Si. When a task changes one of these areas, keep this table true.

| ID | Severity | Finding | How Si handles it | Where |
|---|---|---|---|---|
| F-01 | High | Auto-delivery races your prompt; your message is rejected | Deliveries only at safe moments; in your own sessions your input always wins (a steer becomes a follow-up while you type) | T03.06, T04.08, T04.12 |
| F-02 | High | Report-triggered Main runs bypass `before_agent_start` | Not applicable: there is no Main session woken by reports; the Lead is a stateless call and workers are prompted over RPC | T12.04, T06.04 |
| F-03 | High | `offered` recorded on a fire-and-forget send; failures never retried | RPC commands are correlated with responses by id; bridge controls have acks and timeouts; a delivery counts only after its response | T03.05, T03.06, T04.08 |
| F-04 | High | Quarantine with no exit; the lock is retained | No lock files for work; git locks are in memory and monitored; leases are released when their holder dies; reconcilers handle lost sessions | T01.01, T01.06, T11.02, T11.04 |
| F-05 | High | Worker session hard ceiling of about 16 MB | Oversized RPC records are skipped, not fatal; no whole-transcript commands; a session-size watch starts fresh sessions; restarts reopen sessions through Pi itself | T03.05, T03.06, T03.07, T05.07, T11.02 |
| F-06 | High | Compaction in the prompt preflight exceeds the 30 s deadline | `prompt` and `compact` get 15-minute deadlines extended by compaction events; a timeout never stops a session; contract-tested | T03.06, T04.11 |
| F-07 | High | Any extension-initiated turn kills the worker | The controller's state follows Pi's events, whatever started the turn | T03.06 |
| F-08 | High | Evidence capture copies the whole tree | Freeze with a temporary index and `git write-tree`, hashing only changed files; under 1 s on 5,000 files | T01.05 |
| F-09 | High | "One writer" per Main session, not per repository | One writer per worktree; landing is serialized per repository by the merge queue; your working tree is touched only by an approved `merge_local` | T06.06, T09.10 |
| F-10 | Medium-High | Docs contradict the default delivery | Delivery defaults are defined once (branch, no approval); plan rules keep docs and settings in sync | 05, 06, T06.07 |
| F-11 | Medium | Offer persisted, then the report may be dropped | `si_report` is stored (latched per round) before Si replies | T06.01, T06.03 |
| F-12 | Medium | `delivery_pending` is a dead end | Every state machine has explicit exits; blocked and escalated states create inbox items; reconcilers requeue stuck items | 03 §3, T11.05, T11.06 |
| F-13 | Medium | Inbox redeliver causes duplicate turns | Resolving an inbox item works once; feedback is sent once per round | T05.06, T06.05 |
| F-14 | Medium | Half-applied state snapshots | State and events are written in one database transaction | T00.07 |
| F-15 | Medium | A capture error stops the worker and discards the review | Freeze retries after a quiet period, excludes special and oversized files, and never stops the worker or discards its work | T01.05, T06.05 |
| F-16 | Medium | Evidence blind spots and mis-attribution | Ignored files are documented as outside the evidence and mentioned in `si review` output; workers use their own worktrees, so your edits are never attributed to them | T01.04, T01.05, T05.05 |
| F-17 | Medium | Unenforced config; no default budget | Interim caps per review and per task in the first stage; budgets with defaults from M08 | T05.04, T06.05, T08.02 |
| F-18 | Medium | "Inspected" means any inspect call | Blocking findings need evidence; planted-bug canaries measure what reviewers catch; reviewer precision is tracked | T05.02, T12.05, T13.02 |
| F-19 | Medium | Stale-lock race; a lock can become permanent | The only lock-like file is the pid file, ignored when its process is dead | T00.09 |
| F-20 | Medium | Worker gating depends on Fabric internals | Workers are restricted through documented Fabric settings in per-profile agent directories; the adapter's use of internals is version-pinned and contract-tested | T03.02, T10.01, T11.08 |
| F-21 | Medium | The post-compaction task packet uses `nextTurn` | Workers can re-read their task at any time with `si_task`; the builder prompt tells them to | T06.03, T06.04 |
| F-22 | Medium | Report turns can start during a manual `/compact` | A `compacting` flag holds all deliveries | T03.06 |
| F-23 | Medium | Main's Fovea reacts to worker edits | Not applicable: each worker has its own worktree and Fovea state, and no Main session watches their files | T01.04 |
| F-24 | Medium | Quit waits about 10 s per worker; persistence per Main session | Sessions belong to Si, not to a Main session; stopping is bounded (EOF, then signals) | T03.04 |
| F-25 | Medium | Strict whitelists turn upstream changes into faults | Unknown fields and event types are ignored; adapter version allowlists skip features instead of failing | T03.05, T04.01, T10.02, T10.05 |
| F-26 | Medium | No tests for a concurrent state machine | PropCheck stateful tests, scripted sessions and contract tests | T06.01, T08.03, T12.03, T03.03, T04.11 |
| F-27 | Low | Cancel revokes before validation | Transitions validate before changing anything | T06.01 |
| F-28 | Low | Hashes are key-order sensitive | Hashes over canonical JSON | T09.01 |
| F-29 | Low | No fsync after rename | File data is synced before rename; the database holds all critical state; a directory fsync is not available from the BEAM (documented) | T00.03, T10.02 |
| F-30 | Low | Unbounded state and evidence growth | Retention and `si gc`; worktree and snapshot cleanup; toolchain GC; backup rotation | T11.11, T11.03, T11.08, T11.10 |
| F-31 | Low | Cache warming inert on Pi 0.87.1 | Si does not warm caches; it uses long retention and affinity headers instead | T08.09 |
| F-32 | Low | BRANCH_STALE after history navigation | Not applicable: Si sessions don't use Pi's tree navigation | — |
| F-33 | Low | Frequent persistence and fsync of telemetry | `last_event_at` written at most once per second; analytics inserted per batch | T03.06, T04.06 |
| F-34 | Low | Run token not bumped for report-triggered runs | Not applicable: no report-triggered Main runs | — |
| F-35 | Low | One stray stdout line kills the worker | Non-JSON lines are logged and counted, never fatal | T03.05, T03.06 |
| F-36 | Low | Finalize races abort | The controller serializes commands; reports are latched per round and freezing waits for the turn to settle | T03.06, T06.05 |
| F-37 | Low | Architecture and ledger docs drift | Tasks that add events or settings update the catalog tables in the same change | 03, 05 |
| F-38 | Info | Tarball dominated by a PNG | Not applicable: the bridge package ships no large assets | — |
| F-39 | Info | Staged layer typechecked every run | Not applicable | — |
