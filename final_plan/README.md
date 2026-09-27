# Si · final plan

This folder is the implementation plan for **Si**, an Elixir/OTP control plane for Pi + Fabric coding agents. It is written for implementation agents (and for you): every task is atomic, has exact deliverables, tests, acceptance criteria and verification commands.

Nothing here is implemented yet. The published architecture page (the "Si Blueprint", v9, synced with this plan on 27 September 2026) is the overview for humans: https://claude.ai/artifact/FgCs3uQwxm46JamjE5Apv2. If the two ever differ, **this plan wins**.

## Astra first

The first usable feature is Astra: `si review` freezes a branch or working tree, runs the repository's checks, and has Astra review it on a model from a different family. The build order puts the 40 tasks Astra needs first (★ in the index). From task T05.10 on, Astra reviews every later task of this plan before it counts as done.

## Start implementing

### With Pi

1. Git is ready: your identity is set, and the repository's `main` (the plan) is on GitHub as `git@github.com:asx8678/si.git`. The agent pulls `main` before each task and pushes only when you ask.
2. Open Pi in the repository: `cd /Users/adam2/projects/skynet && pi`. Pi loads [`../AGENTS.md`](../AGENTS.md) by itself: the rules and the per-task procedure. When Pi asks whether to trust the project, say yes. That also loads `.pi/settings.json` (model `openai-codex/gpt-6-astra`, thinking `xhigh`) and the commands below.
3. Type `/si-next`. The agent checks the environment, builds T00.01 and reports back. After each task, start a fresh session with `/new` and type `/si-next` again.

| Command | What it does |
|---|---|
| `/si-next [n]` | Implements the next task (or the next n), finishing an interrupted task first |
| `/si-task <ID>` | Implements one given task once its dependencies are done |
| `/si-plan <ID>` | Plans a task without changing files; use it at `max` thinking before a large task |
| `/si-check` | Runs the after-task checks on the current task branch and reports each expected and actual result, then fixes or redoes what doesn't match |
| `/si-redo <ID> [reason]` | Redoes a task whose result is not what it should be: the part named, or the whole task from a fresh branch |
| `/si-status` | Progress, unfinished and blocked tasks, and what comes next |

If you don't trust the project, the commands and settings don't load, but `AGENTS.md` still does. Type "Implement the next Si task, following AGENTS.md" instead of `/si-next`.

### Models and thinking

- **Writing code:** `openai-codex/gpt-6-astra` at `xhigh`, as set in `.pi/settings.json`. Change it there, or for one session with `/model` and `/thinking`. Its context window is 272K tokens, so use one session per task.
- **Planning a large task:** the 11 size L tasks are T03.06, T05.04, T05.08, T06.04, T06.05, T06.06, T07.02, T08.03, T09.03, T09.04 and T09.06. For these, run `/thinking max` and `/si-plan <ID>`, read the plan and answer its questions, then run `/thinking xhigh` and `/si-task <ID>` in the same session. Switch to `max` too when Astra returns `REVISE` twice in a row, or to sort out a blocked task.
- **Astra (from T05.10):** she runs on the review node and must use a model from a different family than the one writing the code, for example `xai/grok-4.7` at `xhigh` (billed per token) or `zro/kimi-k3`. The agent asks you which one when it sets up the review node.

### Other coding agents

Give them [AGENT_PROMPT.md](AGENT_PROMPT.md). It has the same rules and procedure as `AGENTS.md`, as one prompt, and starts with an environment check and task T00.01.

## Contents

| File | What it holds |
|---|---|
| [00-overview.md](00-overview.md) | What Si is, goals, non-goals, skipped topics, roles, versions, glossary |
| [01-architecture.md](01-architecture.md) | Components, layers, supervision tree, runtimes, flows, Fabric boundary, key decisions |
| [02-repo-layout.md](02-repo-layout.md) | Repository tree, module map, dependencies, `$SI_HOME`, environment variables, naming |
| [03-data-model.md](03-data-model.md) | IDs, tables, state machines, event catalog |
| [04-protocols.md](04-protocols.md) | Pi RPC usage, Si bridge protocol v1, si-adapter protocol, CLI transport |
| [05-schemas-and-config.md](05-schemas-and-config.md) | Settings, repo profile, tool payloads, workflows, prompts, model families |
| [06-quality-and-testing.md](06-quality-and-testing.md) | Definition of done, verification rules, test layers, scripted models, `bin/ci` |
| [07-build-order.md](07-build-order.md) | Stages, milestones, exit demos, parallel lanes, critical path, per-task procedure |
| [08-later.md](08-later.md) | Later items and skipped topics |
| [09-pair-audit-coverage.md](09-pair-audit-coverage.md) | Where each of the 39 findings from your Pair audit is handled |
| [10-after-each-task.md](10-after-each-task.md) | What to do after writing each task: the checks, the expected results, and how to fix or redo work that doesn't match |
| [AGENT_PROMPT.md](AGENT_PROMPT.md) | The prompt for the implementation agent |
| [`../AGENTS.md`](../AGENTS.md), `../.pi/` | What Pi loads in the repository: the rules, the per-task procedure, model settings and the `/si-*` commands |
| [tasks/INDEX.md](tasks/INDEX.md) | All 126 tasks by milestone with dependencies |
| [tasks.yaml](tasks.yaml) | Machine-readable task list with status |
| `tasks/<milestone>/<ID>-<slug>.md` | One file per task |

## For implementation agents

1. Read `00-overview.md`, `01-architecture.md` and `06-quality-and-testing.md` once.
2. Take a task whose dependencies are all `done` in `tasks.yaml`; follow the procedure in `07-build-order.md` §6.
3. After writing a task, work through its **After implementing** section and the loop in `10-after-each-task.md` until every check shows its expected result. A task whose result differs from the expected one is not done: it is fixed or rewritten, never passed by changing what is expected.
4. Each task file has: Goal, Context, Deliverables, Specification, Tests, Acceptance criteria, Verify, After implementing, Out of scope, Notes. Implement exactly that; if something is wrong or impossible, mark the task `blocked` and explain instead of redesigning.
5. Never implement skipped topics (`00-overview.md`, "Skipped"). The builder approval policy is the owner's choice, made with `si init`; never pick it for them.
6. Facts about Pi, Fabric and Fovea in the tasks were checked against the local repositories on 27 September 2026 (Pi 0.87.1, Fabric 0.97.0, Fovea 0.31.1). When a task says "check X in the Pi source", do so before relying on a field name.

## Status tracking

`tasks.yaml` holds each task's `status`: `todo`, `in_progress`, `review`, `done` or `blocked`. Completion notes go to `final_plan/status/<ID>.md`.
