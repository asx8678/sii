# 06 · Quality, testing and verification

## 1. Definition of done (every task)

A task is done only when **all** of these hold:

1. Work is on branch `task/<ID>-<slug>` from the current `main`, in commits prefixed `<ID>: `.
2. Every item in the task's **Acceptance criteria** is met.
3. Every command in the task's **Verify** section was run and produced the stated result. Paste the command output summary in the task's completion note (PR description or `final_plan/status/<ID>.md`).
4. `bin/ci` passes (format, compile with warnings as errors, credo strict, all tests with warnings as errors; TypeScript lint, typecheck and tests for each package that exists).
5. New code has tests. Public functions have `@doc` and `@spec`; modules have `@moduledoc`.
6. No unrelated changes. No new dependencies unless the task lists them.
7. `final_plan/tasks.yaml`: the task's `status` is set to `done`, and the completion note `final_plan/status/<ID>.md` exists, both committed **before** the final Astra review, so the approved tree is exactly what gets merged.
8. **From task T05.10 on:** `bin/task-review` (Astra, running on the separate review node) returns `approve` for the branch as it will be merged. Blocking findings are fixed or disputed with evidence; notes may be left with a reply. Any change after the approval needs a new review.
9. The after-task loop in [`10-after-each-task.md`](10-after-each-task.md) §2 is complete. It holds when:
   - `bin/task-check --final` passes;
   - every Verify command and every check in the task's **After implementing** section showed its expected result;
   - each acceptance criterion has recorded evidence;
   - one deliberate break of the code made a test fail.
   A result that differs from the expected one is never accepted: the work is fixed or rewritten until it matches.

## 2. How to verify a task

- Verification must be **mechanical**: commands with expected exit codes or outputs, or tests that assert behavior. "Looks right" is not verification.
- Each task lists its own test files and test cases. Tests are the primary evidence; CLI commands in **Verify** are the secondary evidence.
- Tests that need time (sessions, reviews) use scripted models (`si-faux`) and finish in under 30 s each. Tag slow tests `@tag :slow` (excluded by default, included in `bin/ci --full`).
- Tests needing the real `pi` binary are tagged `@tag :pi` and run in `bin/ci --full` and `bin/contract-test`. They use the pinned toolchain.
- Never call real model providers in tests. `PI_OFFLINE=1` is set for every Pi process started by tests.

## 3. Test layers

| Layer | Tooling | Used for |
|---|---|---|
| Unit | ExUnit | pure functions, parsers, schemas, state machines |
| Property | StreamData (`ExUnitProperties`), PropCheck (stateful) | framing, diff parsing, ID ordering, state machine invariants, scheduler limits |
| Git fixtures | `Si.Test.Git` (temp repos) | anything touching git |
| Scripted sessions | `testing/pi-faux` + `Si.Test.Faux` | sessions, bridge, Astra, dispatcher, loops |
| Channel | `Phoenix.ChannelTest` | bridge server side |
| LiveView | `Phoenix.LiveViewTest` | cockpit pages |
| TypeScript | vitest | bridge and adapter units |
| Contract | `bin/contract-test` (real Pi 0.87.1 + bridge + faux) | every Pi hook and control the bridge relies on |
| Golden replay (M11) | recorded event streams | decisions stay identical |
| Chaos (M11) | `bin/chaos` | kill sessions, drop connections, 429 storms |

## 4. Scripted models (`si-faux`)

`testing/pi-faux/src/index.ts` is a Pi extension that registers provider `si-faux` using Pi's `fauxProvider` (pattern from Pi's own regression test `packages/coding-agent/test/suite/regressions/8964-extension-provider-streaming.test.ts`). It reads `SI_FAUX_SCRIPT`, a JSON file:

```json
{
  "model": "scripted",
  "steps": [
    {"text": "Reading the task."},
    {"tool_calls": [{"name": "si_task", "arguments": {}}]},
    {"tool_calls": [{"name": "write", "arguments": {"path": "src/a.ts", "content": "export const a = 1;\n"}}]},
    {"tool_calls": [{"name": "si_report", "arguments": {"status": "done", "summary": "Added a.", "tests_run": []}}]}
  ]
}
```

Each step becomes one scripted assistant message (`fauxAssistantMessage` with `fauxText` / `fauxToolCall` blocks). When steps run out, the provider returns an error message `"si-faux: script exhausted"`, which makes test failures obvious. Elixir helper: `Si.Test.Faux.script!(steps) :: path` writes a temp script; `Si.Test.Faux.session_opts(path)` returns the provider/model/env needed to start a session with it.

## 5. Astra reviewing this plan's own tasks

Astra runs on a **review node**: a separate Si built from a detached checkout of `main` in `$HOME/.si-review/checkout`, with its own home and port 4041. It is set up with `bin/review-node setup --astra-model <the owner's choice>`, and refreshed with `bin/review-node update` after every merge to `main`. She never runs from the working copy being changed.

From T05.10 on, `bin/task-review` runs (against the review node):

```
si review . --base main --head HEAD --task-file final_plan/tasks/<milestone>/<ID>-*.md
```

It freezes the branch, runs Si's own checks (Si's `.si/repo.yml`), and has Astra review the diff against the task file's acceptance criteria. The implementation agent fixes blocking findings in the same branch and runs it again until Astra approves (max 5 rounds; then the owner decides).

## 6. Performance budgets checked by tests

| Operation | Budget | Task |
|---|---|---|
| Freeze on a 5,000-file repo (second run) | < 1 s | T01.05 |
| Bridge overhead per turn | < 1% of turn time, and < 5 ms per batched event flush | T04.11 |
| Controller event handling | < 1 ms per event (p95) | T03.05 |
| Seeded Fovea start on the Pi monorepo | < 1 s | T10.02 |
| `si status` round trip | < 300 ms | T00.09 |

## 7. `bin/ci`

```
bin/ci            # default
  mix format --check-formatted
  mix compile --warnings-as-errors
  mix credo --strict
  mix test --warnings-as-errors  # excludes :slow and :pi
  for bridge/, testing/pi-faux/ and adapter/, once each exists:
    npm ci && npm run lint && npm run typecheck && npm test
bin/ci --full     # also: mix test --include slow --include pi ; bin/contract-test
```

Each part prints a one-line PASS/FAIL summary; the script exits non-zero on the first failure.

## 8. `bin/task-check`

`bin/task-check [--final] [ID]` (T00.02) runs the mechanical gates every task must pass before it counts as done:
- `task`, `branch`, `clean`, `scope` and `hygiene`;
- `ci`, which runs `bin/ci`;
- `docs`, which runs `mix si.doc_check`;
- `tests`: the task's test files, three runs in a row;
- `leftovers`;
- with `--final`, the completion note and status.

The gates and what to do when one fails are in [`10-after-each-task.md`](10-after-each-task.md) §3; the whole post-task loop is in §2 there.
