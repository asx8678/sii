# 02 · Repository layout, modules and dependencies

The repository root is `/Users/adam2/projects/skynet` (it may be renamed to `si` later; nothing may hard-code the folder name). The Elixir application lives at the root; TypeScript packages live in subdirectories.

## 1. Tree

```
/                                   repository root (git, branch main)
├─ AGENTS.md                        rules for coding agents: Si's text, then Phoenix's generated guidelines (Pi and Astra load it)
├─ .pi/                             Pi settings and prompt templates for the agent implementing Si (settings.json, prompts/si-*.md)
├─ mix.exs  mix.lock  .formatter.exs  .credo.exs  .tool-versions
├─ config/                          config.exs, dev.exs, test.exs, runtime.exs
├─ lib/
│  ├─ si/                           core (contexts listed below)
│  ├─ si_web/                       Phoenix: endpoint, router, LiveViews, bridge socket/channel
│  ├─ si.ex  si_web.ex
│  └─ mix/tasks/si.doc_check.ex     `mix si.doc_check`: missing @moduledoc/@doc/@spec (used by bin/task-check, T00.02)
├─ priv/
│  ├─ repo/migrations/              one migration per task that adds tables
│  ├─ default_config.yml            defaults for $SI_HOME/config.yml
│  ├─ prompts/                      versioned prompts: astra/review.md, astra/fix.md, builder/task.md, lead/plan.md, ...
│  ├─ workflows/                    built-in templates: quick.yml, standard.yml, full.yml, review-only.yml, fix-tests.yml
│  └─ models.yml                    model catalog: family, prices, capabilities (from M13; minimal from M05)
├─ protocol/                        JSON Schemas shared by Elixir and TypeScript
│  ├─ config.schema.json  repo_profile.schema.json  workflow.schema.json
│  ├─ tools/                        si_task, si_report, si_ask, si_scope, si_verdict, si_plan, si_dispute (*.schema.json)
│  ├─ bridge/v1/                    join, events, requests, controls (*.schema.json)
│  ├─ adapter/v1/                   ops (*.schema.json)
│  └─ compat.yml                    tested version matrix (Pi, Fabric, Fovea, bridge)
├─ bridge/                          Si bridge: Pi extension package (TypeScript)
│  ├─ package.json  tsconfig.json  biome.json  vitest.config.ts
│  ├─ src/index.ts                  extension entry (default export (pi) => {...})
│  ├─ src/connection.ts  src/events.ts  src/tools.ts  src/controls.ts  src/slots.ts  src/fabric.ts  src/status.ts
│  └─ test/
├─ adapter/                         si-adapter: Node program (TypeScript), from M10
│  ├─ package.json  tsconfig.json  src/main.ts  src/framing.ts  src/ops/*.ts  test/
├─ testing/
│  └─ pi-faux/                      Pi extension registering the scripted provider `si-faux` for tests
├─ cli/                             `si` escript (separate small Mix project)
│  ├─ mix.exs  lib/si_cli.ex
├─ bin/
│  ├─ ci                            full local CI (Elixir + TypeScript)
│  ├─ task-check                    after-task gates for the current task branch (T00.02; 10-after-each-task.md §3)
│  ├─ si-server                     start the Si node in dev
│  ├─ contract-test                 bridge contract tests against the pinned Pi
│  ├─ task-review                   Astra review of the current task branch (from T05.10)
│  ├─ review-node                   the separate, stable Si that runs those reviews (T05.10)
│  ├─ chaos                         chaos test suite (T11.09)
│  ├─ si-install                    build the release and escript, install the service and `si` on PATH (T11.12)
│  └─ si-restore                    restore a database backup (T11.10)
├─ evals/                           eval suites: evals/<suite>/<task>/task.yml + hidden_tests.patch (M07)
├─ test/                            ExUnit tests mirroring lib/
│  └─ support/                      Si.Test.* helpers (temp home, git repos, faux sessions, eventually)
├─ docs/GUIDE.md                    user guide (T05.11)
├─ notebooks/                       Livebook notebooks (from M13)
└─ final_plan/                      this plan
```

## 2. Elixir module map

| Context | Modules (main ones) | Owns |
|---|---|---|
| Platform | `Si.Application`, `Si.Paths`, `Si.Settings`, `Si.Id`, `Si.Repo`, `Si.Events`, `Si.Trace`, `Si.Telemetry` | home dir, config, DB, IDs, event log, tracing |
| CLI | `Si.CLI.Server`, `Si.CLI.Commands.*`, `Si.CLI.Output`; escript `SiCli` in `cli/` | command dispatch, output streaming |
| Git | `Si.Git`, `Si.Git.Error`, `Si.Git.Locks`, `Si.Git.Porcelain` | git command execution and parsing |
| Repos | `Si.Repos`, `Si.Repos.Repo` (schema), `Si.RepoProfile`, `Si.RepoProfile.Detect` | registry, `.si/repo.yml` |
| Worktrees | `Si.Worktrees`, `Si.Worktrees.Worktree`, `Si.Worktrees.Cow` | worktree lifecycle, copy-on-write caches |
| Evidence | `Si.Evidence`, `Si.Evidence.Snapshot` | freeze, snapshots, approvals |
| Checks | `Si.Checks`, `Si.Checks.Command`, `Si.Checks.Pool`, `Si.Checks.Check` (behaviour), `Si.Checks.{Format,Build,Lint,Tests,DiffCoverage,Mutation,TestIntegrity,Scope}`, `Si.Diff`, `Si.Lcov`, `Si.StrykerReport` | check pipeline |
| Toolchains | `Si.Toolchains`, `Si.Toolchains.Toolchain` | pinned Pi/Fabric/Fovea installs |
| Profiles | `Si.Profiles` | Pi agent dirs per role |
| Runner | `Si.Runner` (behaviour), `Si.Runner.Local`, `Si.Runner.Local.PortOwner`, `Si.OsProcess` | OS processes |
| Pi RPC | `Si.Pi.Rpc`, `Si.Pi.Jsonl` | JSONL framing, requests, events |
| Sessions | `Si.Sessions`, `Si.Sessions.Session` (schema), `Si.Sessions.Controller`, `Si.Sessions.SessionSup` | session lifecycle and state |
| Bridge | `SiWeb.BridgeSocket`, `SiWeb.SessionChannel`, `Si.Bridge.Protocol`, `Si.Bridge.Tools`, `Si.Bridge.Ingest`, `Si.Bridge.Token` | bridge server side |
| Review | `Si.Review`, `Si.Review.Thread`, `Si.Review.Verdict`, `Si.Review.Context`, `Si.Review.Fix`, `Si.Review.Policy`, `Si.Review.Canary`, `Si.Review.Dispute` | Astra |
| Models | `Si.Models`, `Si.Models.Catalog`, `Si.Models.Scoreboard`, `Si.Models.Router` | families, routing |
| Inbox | `Si.Inbox`, `Si.Inbox.Item` | items waiting on you |
| Tasks | `Si.Tasks`, `Si.Tasks.Task`, `Si.Tasks.Attempt`, `Si.Tasks.Dispatcher`, `Si.Tasks.Loop` | task board, dispatch, build-review loop |
| Merge queue | `Si.MergeQueue`, `Si.MergeQueue.Queue`, `Si.MergeQueue.Item` | landing |
| Delivery | `Si.Delivery` | branch, pr, patch, merge_local |
| Ledger | `Si.Ledger` | summaries |
| Evals | `Si.Evals`, `Si.Evals.TaskSpec`, `Si.Evals.Arms`, `Si.Evals.Report` | eval harness |
| Capacity | `Si.Cost`, `Si.Budgets`, `Si.Scheduler`, `Si.Scheduler.Pool`, `Si.Memory`, `Si.WarmSlots` | cost, admission |
| Workflows | `Si.Workflows`, `Si.Workflows.Schema`, `Si.Workflows.Validator`, `Si.Runs`, `Si.Runs.Run` | workflows and runs |
| Planning | `Si.Lead`, `Si.Plan`, `Si.Plan.Graph`, `Si.Intake` | plans and intake |
| Adapter | `Si.Adapter`, `Si.Fovea`, `Si.FabricMesh` | Node adapter |
| Reliability | `Si.Reconcilers.*`, `Si.Backups`, `Si.Versions` | repair, pinning, backups |
| Signals | `Si.Signals`, `Si.Jev`, `Si.Interventions` | L2 and ladder |
| Learning | `Si.Learning`, `Si.Prompts` | lessons, prompt versions |
| Web | `SiWeb.Router`, `SiWeb.Layouts`, `SiWeb.*Live` | cockpit |

Rules for implementers:
- Context modules expose plain functions; LiveViews and the CLI call only context functions, never `Si.Repo` directly.
- Every public function has `@spec` and `@doc`. Every module has `@moduledoc`.
- Structs for results (`%Si.Checks.Result{}` etc.) instead of loose maps at context boundaries.
- No new top-level supervisor children except those a task explicitly adds.

## 3. Hex dependencies (constraints verified 27 Sep 2026)

| Package | Constraint | Used for | Added in |
|---|---|---|---|
| phoenix | `~> 1.8` | web, channels | T00.01 (generator) |
| phoenix_live_view | `~> 1.2` | cockpit | T00.01 |
| phoenix_ecto | `~> 4.7` | Ecto + Phoenix | T00.01 |
| ecto_sqlite3 | `~> 0.25.0` | SQLite | T00.01 |
| bandit | `~> 1.12` | HTTP server | T00.01 |
| jason | `~> 1.4` | JSON | T00.01 |
| yaml_elixir | `~> 2.12` | YAML config, repo profile, workflows | T00.02 |
| jsv | `~> 0.25.0` | JSON Schema validation | T00.02 |
| muontrap | `~> 2.0` | check commands with process-tree cleanup | T00.02 |
| req | `~> 0.7.4` | HTTP (Jev, misc) | T00.02 |
| req_llm | `~> 1.25` | direct model calls (judgments, Lead activations, lesson summaries) | T12.02 |
| opentelemetry_api | `~> 1.5` | tracing API | T00.02 |
| opentelemetry | `~> 1.7` | tracing SDK | T00.02 |
| opentelemetry_exporter | `~> 1.11` | OTLP export | T13.06 |
| libgraph | `~> 0.16.0` | plan and workflow graphs | T09.01 |
| credo | `~> 1.7` | lint (dev/test) | T00.02 |
| dialyxir | `~> 1.4` | types (dev) | T00.02 |
| propcheck | `~> 1.5` | stateful property tests (test) | T00.02 |
| stream_data | `~> 1.4` | property tests (test) | T00.02 |
| mox | `~> 1.3` | behaviour mocks (test) | T00.02 |
| lcov_ex | `~> 0.3.6` | coverage in LCOV for Si's own tests (test) | T02.07 |

Do not add other dependencies without recording the reason in the task's PR description.

## 4. Node/TypeScript packages

| Package | Location | Key dependencies |
|---|---|---|
| `@si/pi-bridge` | `bridge/` | peer: `@earendil-works/pi-coding-agent` 0.87.1, `typebox` (1.3.x, as used by Pi); runtime: `phoenix` (JS channel client); dev: `vitest`, `@biomejs/biome`, `typescript` |
| `@si/pi-faux` | `testing/pi-faux/` | peer: `@earendil-works/pi-coding-agent`, `@earendil-works/pi-ai` (for `fauxProvider`) |
| `@si/adapter` | `adapter/` | `pi-fabric` 0.97.0 and `pi-fovea` 0.31.1 (same versions as the toolchain), `tsx` (runs Fovea's TypeScript sources); dev: `vitest`, `typescript` |

Pi loads extension TypeScript source directly (Fovea's `package.json` uses `"pi": {"extensions": ["./src/index.ts"]}`), so the bridge needs no build step.

## 5. `$SI_HOME` layout (default `~/.si`, tests use a temp dir)

```
$SI_HOME/
├─ config.yml                 your settings (optional)
├─ si.db  si.db-wal  si.db-shm
├─ cookie                     Erlang distribution cookie (0600)
├─ bridge_token               bridge auth token (0600)
├─ cockpit_token              cockpit login token (0600, T00.12)
├─ si.pid                     single-instance guard: os pid + node name (T00.09)
├─ env                        optional KEY=value lines for Si's own model calls (0600, T12.02)
├─ toolchains/<tc_id>/        npm prefix with pinned Pi, Fabric, Fovea
├─ profiles/<name>/           Pi agent dirs: settings.json, models.json (link), auth.json (link), fabric.json
├─ sessions/                  Pi session store for Si sessions (`--session-dir`; Pi names the files)
├─ worktrees/<repo_id>/<wt_id>/
├─ checks/<repo_id>/<n>/      check pool worktrees
├─ queue/<repo_id>/           merge queue worktree
├─ logs/  logs/node.log (rotated)  logs/checks/<snp_id>/<check>.log  logs/sessions/<ses_id>.stderr.log
├─ patches/  backups/  evals/
```

## 6. Environment variables

| Variable | Read by | Meaning |
|---|---|---|
| `SI_HOME` | Si, CLI | Home directory (default `~/.si`) |
| `SI_NODE` | CLI | Target node name (default `si@<short hostname>`) |
| `SI_BRIDGE_URL` | bridge | WebSocket URL, e.g. `ws://127.0.0.1:4040/bridge/websocket` |
| `SI_BRIDGE_TOKEN` | bridge | Token (Si sets it for its sessions; your sessions read `$SI_HOME/bridge_token`) |
| `SI_SESSION_ID` | bridge | Set by Si for sessions it starts |
| `SI_ROLE`, `SI_RUN_ID`, `SI_TASK_ID`, `SI_PARENT_SESSION_ID` | bridge | Context for events |
| `SI_BRIDGE_MODE` | bridge | `observe`, `suggest` or `control` for your sessions (default `observe`) |
| `SI_FAUX_SCRIPT` | pi-faux | Path to a JSON script of scripted model responses (tests) |
| `PI_CODING_AGENT_DIR` | Pi | Agent dir (Si sets it to a profile dir) |
| `PI_OFFLINE` | Pi | `1` in tests to stop network activity |
| `PI_CACHE_RETENTION` | Pi | Set by Si per session from `cache.retention` (default `long`) |
| `SI_CACHE_AFFINITY_HEADER` | bridge | Header name the bridge adds with the session id, when a `cache.affinity` rule matches (T08.09) |
| `MIX_TEST_PARTITION` | Si tests, check commands | Test DB partition |

## 7. Naming conventions

- IDs: prefixed ULIDs from `Si.Id` (see `03-data-model.md`), e.g. `ses_01J9Z3...`.
- Git refs owned by Si: `refs/heads/si/integration`, `refs/heads/si/task/<tsk_id>`, `refs/heads/si/astra-fix/<rev_id>`, `refs/si/snapshots/<snp_id>` (keeps snapshot commits from garbage collection).
- Branches for implementing this plan: `task/<task-id>-<slug>`, e.g. `task/T05.04-review-run`.
- Commit messages for this plan: `T05.04: <imperative summary>`.
