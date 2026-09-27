# 00 · Overview

## What Si is

Si is a control plane for coding agents, written in Elixir/OTP (Phoenix + LiveView). It does not implement an agent loop itself. Pi sessions with the Fabric extension do the coding; Si decides what they work on, checks what they produce, reviews it with a second model (Astra), lands it safely, and measures everything.

- **You** give Si goals or tasks (CLI `si` or the LiveView cockpit).
- **Si** plans (through a Lead agent), dispatches tasks to Pi sessions, freezes each result, runs deterministic checks, has **Astra** review it on a different model family, and lands approved work through a merge queue.
- **Pi + Fabric** sessions do the reading, editing and running. A small Si extension inside every session (the **Si bridge**) reports what the agent does and carries out Si's controls.

## Goals

1. **Astra first.** The first usable feature is `si review`: freeze any branch or working tree, run the repository's checks, and have Astra review it on another model. From milestone M05 on, every task of this plan is itself reviewed by Astra before it counts as done.
2. Reuse Pi, Fabric and Fovea instead of rebuilding them.
3. Deterministic before LLM: anything that can be computed (checks, scheduling, merging, budgets) is computed, not judged by a model.
4. Every result is bound to evidence: a frozen git tree SHA, the exact commands run, their exit codes and logs.
5. Every claim is measured: an eval harness compares Si with a single Pi session against numeric targets.
6. OpenAI and open models first (through Pi's providers). Anthropic may be added later the same way.

## Non-goals

- Reimplementing Pi's agent loop, tools or providers.
- A native Elixir code mode (Fabric's `fabric_exec` is used).
- Multi-machine operation in the first version (the runner interface keeps it possible later).
- Windows. Si targets macOS and Linux.
- Anything listed under **Skipped** below.

## Skipped (out of scope for this plan)

These topics were deliberately left out by the owner and will be planned separately. Tasks must not implement them and must not invent substitutes:

1. **Self-healing and dev mode for Si itself** (Si fixing and hot-upgrading its own code).
2. **The safety group:** worker isolation profiles, command policy, prompt-injection handling, a data egress policy, dependency and secret checks, and keeping workers alive / reattaching them across Si restarts.

Basic operational hygiene that the plan does include: the bridge and the cockpit listen on `127.0.0.1` only; the bridge requires a per-machine token and the cockpit a login token with strict origin checks (T00.12); files with tokens are created with mode `0600`.

The **builder approval policy** (which Fabric risk classes builders may use without asking) belongs to the safety topics. The plan does not choose it: `si init` asks you to set it (T05.11), and builders do not start until you do. Reviews by Astra do not need it.

## Roles

| Role | What it is | Does | Never does |
|---|---|---|---|
| You | The owner | Sets goals and tasks; approves pull requests, merges and full-run plans; settles escalations | Misses a request: everything waiting on you is in the inbox |
| Lead | One per run, strong model | Writes acceptance criteria and the plan; handles escalated signals; re-plans | Writes code, approves its own plan, merges |
| Workers (builders) | One Pi + Fabric session per task (or chain of dependent tasks) | Implement a task in their own worktree; fix after review | Merge, approve, touch other tasks |
| Astra | Default reviewer: a Pi session on a model from a different family than the writer's, in her own clean checkout | Reviews plans and changes; fixes small issues when the fix policy allows | Approves her own code; edits a worker's worktree |
| Services | Deterministic Elixir processes | Task board, dispatch, checks, evidence, merge queue, scheduler, budgets, reconcilers | Make judgment calls |

## Pinned versions (verified on 27 September 2026)

| Component | Version | Notes |
|---|---|---|
| Elixir | 1.20.4 | compiled with Erlang/OTP 29 (installed locally) |
| Erlang/OTP | 29 | |
| Phoenix installer | 1.8.13 | `mix phx.new` |
| Phoenix / LiveView | `~> 1.8` / `~> 1.2` | |
| Pi (`@earendil-works/pi-coding-agent`) | 0.87.1 | `/opt/homebrew/bin/pi`; Si installs its own pinned copy (see toolchains) |
| pi-fabric | 0.97.0 | on npm; local clone (docs, source reading) `/Users/adam2/projects/pair/pi-fabric`; requires Node ≥ 24 |
| pi-fovea | 0.31.1 | on npm; local clone `/Users/adam2/projects/pair/pi-fovea` |
| Node.js / npm | 24.21.0 / 11.19.0 | installed locally; Pi requires Node ≥ 22.19 |

Hex packages and their constraints are listed in `02-repo-layout.md`.

## Glossary

| Term | Meaning |
|---|---|
| Run | One execution of a workflow for a goal (quick, standard or full tier). |
| Task | One unit of work on the task board (usually a plan step). Has attempts. |
| Attempt | One try of a task by one worker session; ends with a report (`si_report`) or an interruption. |
| Round | One review cycle of a task: snapshot → checks → Astra verdict. |
| Snapshot | A frozen state of a worktree: tree SHA + a throwaway commit whose parent is the base. Evidence and approvals bind to it. |
| Check | A deterministic command from the repo profile (format, build, lint, tests, diff coverage, mutation, test integrity, scope). |
| Check pool | Pre-created worktrees where checks run on a snapshot, never in the worker's own worktree. |
| Repo profile | `.si/repo.yml` in a repository: its commands, risky paths and parallel-test settings. |
| Verdict | Astra's structured result (`approve` or `revise`) with findings, recorded through the `si_verdict` tool. |
| Finding | One issue: blocking or note, with file, line, category, problem and evidence. |
| Fix policy | Who fixes blocking issues: `writer`, `astra`, or `auto` (default). |
| Integration branch | `si/integration` in each repository; always green; tasks land here through the merge queue. |
| Merge queue | Per-repository service that rebases a snapshot onto the integration head, runs checks, and lands it. |
| Delivery | Where finished work goes: `branch` (default, no approval), `pr`, `merge_local` (both need approval), `patch`. |
| Session | One Pi process (worker, Astra, Lead, critic) or one of your own Pi terminal sessions that joined Si. |
| Controller | The `:gen_statem` in Si that mirrors one session's state and delivers messages at safe moments. |
| Si bridge | Si's Pi extension (TypeScript) loaded in every Si session: reports events, runs controls, adds `si_*` tools, waits for scheduler slots. |
| si-adapter | A small Node process Si supervises; reads Fabric's and Fovea's files with their own code at the pinned versions. |
| Toolchain | A pinned install of Pi + Fabric + Fovea under `$SI_HOME/toolchains/<id>` used by Si sessions. |
| Profile | A Pi agent directory under `$SI_HOME/profiles/<name>` (settings, models, auth links, fabric.json) for a role. |
| Slot | Permission from the scheduler to send one model call. |
| Pool | A scheduler capacity group: one provider account or one GPU server. |
| Reconciler | A process that compares desired state with observed state and repairs the difference idempotently. |
| Ledger | Per-run/per-task summary of attempts, models, costs, checks, verdicts and decisions, built from the event log. |
| Tier | quick, standard or full: how much process a run gets. |
| Template | A built-in workflow (quick, standard, full, review-only, fix-tests) that custom workflows extend. |
| Canary | A known bug planted in a copy of a change to measure a reviewer's catch rate. |
| Inbox | Everything waiting on you: gates, approvals, escalations, disputes, budget stops. |
| `$SI_HOME` | Si's home directory, default `~/.si` (tests use a temporary directory). |

## Reading order

1. This file.
2. `01-architecture.md`: components, layers, flows, key decisions.
3. `02-repo-layout.md`: where code lives, module map, dependencies, home directory.
4. `03-data-model.md`: tables, state machines, events, IDs.
5. `04-protocols.md`: Pi RPC usage, bridge protocol v1, adapter protocol, CLI transport.
6. `05-schemas-and-config.md`: settings, repo profile, workflows, tool schemas.
7. `06-quality-and-testing.md`: definition of done, test layers, verification rules.
8. `07-build-order.md`: milestones and the task graph.
9. `10-after-each-task.md`: what to do after writing each task, the expected results, and when to fix or redo work.
10. The task file you are implementing, under `tasks/`.
