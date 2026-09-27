# 07 · Build order

126 tasks in 15 milestones (26 small, 89 medium, 11 large). The full list with dependencies is in [`tasks/INDEX.md`](tasks/INDEX.md) and, machine-readable, in [`tasks.yaml`](tasks.yaml).

## 1. Principles

1. **Astra first.** Stage A builds only what `si review` needs (40 tasks, marked ★ in the index). At the end of Stage A, Astra reviews any branch or working tree on a different model.
2. **Astra reviews the rest.** From T05.10 on, every task branch must get `approve` from `bin/task-review` before it counts as done (definition of done, item 8).
3. **Bottom-up by layer** inside each stage: platform → git → checks → sessions → bridge → review → tasks → evals → capacity → workflows → adapter → reliability → supervision → models → learning.
4. **One task, one branch, one merge.** Branch `task/<ID>-<slug>` from `main`; merge fast-forward into `main` only after the definition of done holds; update `status` in `tasks.yaml`.
5. **A task starts only when all its `depends_on` tasks are `done`.** Tasks whose dependencies are done can run in parallel on separate branches.

## 2. Stage A: the Astra path (40 tasks)

In this order (a valid topological order; tasks on the same line may run in parallel):

| Step | Tasks | What exists afterwards |
|---|---|---|
| A1 | T00.01 | Phoenix skeleton in the existing repository |
| A2 | T00.02 | Dependencies, credo, `bin/ci` |
| A3 | T00.03, T00.06 | Home paths, IDs |
| A4 | T00.04, T00.05, T00.09 | Settings, SQLite, `si` CLI transport with the single-instance guard |
| A5 | T00.07, T00.11 | Event log, test helpers |
| A6 | T01.01 | Safe git wrapper and locks |
| A7 | T01.02 | Repo registry, integration branch |
| A8 | T01.03, T01.04 | Repo profile (`si repo init`), worktrees (with submodules and LFS) |
| A9 | T01.05, T01.06 | Snapshots (freeze with exclusions), check pool |
| A10 | T02.01, T02.02 | Check command runner, diff analysis |
| A11 | T02.03 | Check pipeline, `si check` |
| A12 | T02.04, T02.05 | Format/build/lint/tests checks, test integrity |
| A13 | T03.01, T03.04 | Pinned toolchain, Port runner |
| A14 | T03.02, T03.03, T03.05 | Profiles (tool allowlists with `si_*`), scripted provider `si-faux`, RPC framing |
| A15 | T03.06 | Session controller (long prompt deadlines, compaction flag) |
| A16 | T03.07 | Sessions API and CLI (`--session-dir` + `--session-id`) |
| A17 | T04.01, T04.03 | Bridge protocol schemas, bridge package |
| A18 | T04.02 | Bridge socket and channel |
| A19 | T04.04 | Bridge connection and status |
| A20 | T04.07 | `si_*` tools |
| A21 | T05.01, T05.02, T05.06 | Model families, verdict storage, inbox |
| A22 | T05.03 | Astra prompt and review context |
| A23 | T05.04 | Review run (with an interim cost cap) |
| A24 | T05.05 | **`si review`** (first usable feature) |
| A25 | T05.07 | Review rounds and escalation |
| A26 | T05.10 | Si's own profile, `bin/task-review`: Astra now reviews every task |

**Stage A demo:** on a branch with a planted off-by-one bug, `bin/task-review` prints `Verdict: REVISE` with a blocking finding on that line and exits 1; after the fix, round 2 prints `APPROVE` and exits 0.

**Right after Stage A**, do T05.11 (`si init`, the settings writer, your choice of the builder approval policy, and the user guide) so you can use Astra on your own repositories. Builders (M06) cannot start until the approval policy is set.

## 3. Stage B: everything else (86 tasks)

Milestones in dependency order with their exit demos. Within Stage B, the lanes in §4 can proceed in parallel.

| Milestone | Tasks | Exit demo |
|---|---|---|
| Rest of M00–M05 | T00.08, T00.10, T00.12, T02.06–T02.08, T03.08, T04.05, T04.06, T04.08–T04.12, T05.08, T05.09, T05.11, T05.12 | `si init` sets everything up; the cockpit requires `si open`, shows sessions and reviews, and starts reviews; contract tests pass (`bin/contract-test`); Astra can fix small issues herself |
| M06 Tasks and single-worker loop | T06.01–T06.09 | `si fix "..."` or a task from the cockpit → a builder works → checks → Astra → lands on `si/integration` → branch `si/task/<id>` |
| M07 Eval harness | T07.01–T07.04 | First eval report: Si quick tier vs a single Pi session on 20 seed tasks, with targets |
| M08 Capacity | T08.01–T08.09 | Three workers in parallel under the scheduler; a 429 halves the pool; `si freeze` stops everything Si started; cache share shown per session |
| M09 Workflows and planning | T09.01–T09.12 | `si run "<goal>"` or a run from the cockpit on the standard tier: plan, critique, fan-out, merge queue, acceptance review, delivery |
| M10 Adapter and Fovea | T10.01–T10.05 | Seeded worktrees start Fovea in under a second; tests chosen by impact; Fabric panel for your sessions |
| M11 Reliability | T11.01–T11.12 | `bin/chaos` passes; backups verify; an upgrade is checked and pinned per run; `si gc` keeps disk use bounded; Si runs as a login service |
| M12 Signals and the Lead | T12.01–T12.06 | A worker that claims done without tests gets a hint; the Lead steers or reassigns; canary catch rate recorded |
| M13 Models and analytics | T13.01–T13.07 | The router beats a fixed assignment on the eval set; analytics answer where time and money went |
| M14 Learning loop | T14.01–T14.04 | A repeated code-mode mistake becomes a lesson and its failure rate drops |

## 4. Parallel lanes after Stage A

Once Stage A is done, these lanes are largely independent (respect each task's `depends_on`):

| Lane | Tasks |
|---|---|
| Setup and cockpit | T05.11 first, then T00.12, T05.12, T06.09, T09.12 |
| Bridge completion | T04.05, T04.06, T04.08–T04.12, then T10.04, T10.05 |
| Checks completion | T02.06, T02.07, T02.08 |
| Review completion | T05.08, T05.09, then T12.05, T12.06 |
| Tasks → evals | M06, then M07 |
| Capacity | M08 (after T04.06, T04.09, T06.04), including cache discipline T08.09 |
| Workflows | M09 (after M06 and T08.08) |
| Adapter | T10.01–T10.03 (after T03.01, T02.04) |
| Reliability and operations | T11.01, T11.10 early; T11.12 (service) as soon as its dependencies are done; the reconcilers and T11.11 as their subjects exist |
| Supervision, models, learning | M12, M13, M14 last |

## 5. Critical path

The longest dependency chain (22 tasks) decides the minimum number of sequential steps:

T00.01 → T00.02 → T00.03 → T00.05 → T00.11 → T01.01 → T01.02 → T01.04 → T01.06 → T02.01 → T02.03 → T05.03 → T05.04 → T05.05 → T05.11 → T06.04 → T06.05 → T06.06 → T06.07 → T07.02 → T07.03 → T07.04

## 6. Procedure per task (for the implementation pipeline)

1. Pick a task whose `depends_on` are all `done` in `tasks.yaml` (Stage A tasks first). Set it to `in_progress`.
2. `git checkout main && git pull --ff-only` (if a remote exists), then `git checkout -b task/<ID>-<slug>`.
3. Read the task file completely, plus the documents it references.
4. Implement exactly the deliverables. Write the listed tests first where practical.
5. Run the after-task loop ([`10-after-each-task.md`](10-after-each-task.md) §2):
   - `bin/task-check`;
   - every Verify command;
   - the task's **After implementing** checks;
   - evidence for each acceptance criterion;
   - a read of the diff, with one deliberate break of the code.
   Every result must match the expected one. Anything else is fixed or rewritten (§4 and §5 there), and the loop starts again at `bin/task-check`.
6. Write the completion note (`final_plan/status/<ID>.md`, template in `10-after-each-task.md` §8) and set the task's status to `done` in `tasks.yaml`, in the same commit. Then run `bin/task-check --final`.
7. From T05.10 on: `bin/task-review` until `APPROVE` (max 5 rounds; then ask the owner). Fixing a finding means a new commit and a new review. Do not edit anything after the final approval: Si keeps the review thread (rounds, findings, verdict) on the review node, so the completion note does not need the verdict.
8. Merge the branch into `main` with a fast-forward (rebase first if `main` moved, then run the loop from `bin/task-check` and, from T05.10 on, `bin/task-review` again). After the merge, run `bin/ci` on `main` and, from T05.10 on, `bin/review-node update`. When the task completes a milestone, run its checkpoint (`10-after-each-task.md` §10).
9. If a task turns out wrong or impossible as specified, stop, set it to `blocked`, and write down why in its completion note. Do not silently change the design.
