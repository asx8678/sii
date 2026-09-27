# 10 · After each task: checks, expected results and redoing work

Every task ends with the same loop: check the work, compare each result with the expected one, and fix or rewrite anything that does not match, then check everything again. This document defines that loop. Each task file adds its own checks in its **After implementing** section.

## 1. The rule

A task is done only when every check shows exactly its expected result. Nearly right is not done. Any of these sends the work back:
- a different exit code;
- a missing or different output line;
- one failing test, or a test that fails only sometimes;
- a new warning;
- a missed time budget;
- a file the task did not ask for;
- a side effect outside the temporary directories.

Work that does not show the expected result is redone until it does: fixed in the code, or rewritten. It is never made to pass by changing what is expected.

## 2. The sequence after writing a task

Do these steps in order. When a step's result differs from the expected one, go to §4 (what to do about it). After any change, start again at step 3, not at the step that failed, because a fix can break something that passed before.

| Step | What to do | Expected result |
|---|---|---|
| 1. Finish | Every Deliverable exists and every test the task file lists is written. Tick them off against the task file. | Nothing from Deliverables or Tests is missing. |
| 2. Commit | Commit the work on the task branch (`<ID>: …` messages). The checks look at commits, not at unsaved files. | `git status --porcelain` prints nothing. |
| 3. Gates | `bin/task-check` (from T00.02; T00.01 does the gates by hand, see §3). | `RESULT: PASS`. Each `WARN` is either fixed or explained under *Deviations* in the completion note. |
| 4. Verify | Run every command in the task's **Verify** section, exactly as written. Run a multi-line block as one shell command, because variables such as `$srv` do not survive between separate tool calls. | The result written next to each command (`# exit=0`, `# 200`, …). Without a written result: exit code 0 and no error output. |
| 5. Task checks | Run every check in the task's **After implementing** section. | The result stated for each check. |
| 6. Acceptance | For each acceptance criterion, name its evidence: the test (file and test name) or the command and its output. | Every criterion has evidence. A criterion without evidence is not met: write the missing test or check. |
| 7. Read the diff | Read `git diff main...HEAD` against the task's Specification with the checklist in §6. Then break the code on purpose once: flip one condition or constant that a test should guard, run that test, and restore the code. | Every checklist answer is "yes". The broken code makes at least one test fail, and restoring it makes all tests pass again. |
| 8. Record | Write the completion note (§8), set the task's status to `done` in `tasks.yaml`, and commit both together. Then run `bin/task-check --final`. | `RESULT: PASS` with `final=yes`. |
| 9. Review | From T05.10 on: `bin/task-review`. | `Verdict: APPROVE`, exit 0. On `REVISE`, every blocking finding counts as a failed check: go to §4, then start again at step 3. |
| 10. Merge | Fast-forward `main` (§9) and run `bin/ci` on `main`. From T05.10 on, also `bin/review-node update`. | `bin/ci` prints `PASS`, and the review node reports the new `main`. |
| 11. Milestone | If this task completed a milestone or Stage A, run its checkpoint (§10). | The checkpoint's expected result. |

## 3. `bin/task-check` gates

`bin/task-check [--final] [ID]` (built in T00.02) runs these gates in order. It does not stop at the first failure. It prints one line per gate, then `RESULT: PASS` or `RESULT: FAIL (<gates>)`, writes the report to `tmp/task-check/<ID>.txt` (first line: `task-check <ID> HEAD <sha> final=<yes|no>`), and exits 0 only when no gate failed.

| Gate | Passes when | Usual cause of a failure → action |
|---|---|---|
| `task` | the task file for `<ID>` exists | wrong branch name → rename the branch |
| `branch` | you are on `task/<ID>-…`, and `main` is an ancestor of `HEAD` | `main` moved → `git rebase main`, then start again at step 3 |
| `clean` | nothing is uncommitted or untracked | commit the work, or delete stray files |
| `scope` | every changed file is named in the task file (its path, its directory, or a module it defines), or is one of `final_plan/tasks.yaml`, `final_plan/status/<ID>.md`, a `final_plan/0*.md` document, `mix.lock`, `package-lock.json` | an unnamed file is a `WARN`: remove it, or explain it under *Deviations* |
| `hygiene` | added lines contain no debug output, no placeholders, no skipped or focused tests, no lint or type suppressions, no `pkill`/`killall`, no `Mix.env` in `lib/` outside `lib/mix/`, no hard-coded `/Users/` paths in source directories, and nothing that looks like a secret | remove it; never suppress a check to pass it (§4) |
| `ci` | `bin/ci` passes (log in `tmp/task-check/<ID>-ci.log`) | read the failing step, fix the cause, start again at step 3 |
| `docs` | `mix si.doc_check` finds no module without `@moduledoc` and no public function or macro without `@doc` and `@spec` in the changed files under `lib/si/` | add the missing docs and specs; hide callbacks with `@impl true` |
| `tests` | every test file the task names exists, and the named Elixir test files pass three runs in a row with `--include slow --include pi --warnings-as-errors`. Files tagged `:contract` or `:chaos` run once. | a failure in any run is a defect, even if the next run passes (§4) |
| `leftovers` | no process started by tests is still running (command lines containing `si_test_home_`, `si_test_repos` or `fake_pi.mjs`), and the test runs did not change this repository's branches, `refs/si/*` or worktrees | tests must clean up and must use temporary repositories: fix the test setup |
| `final` (with `--final`) | the completion note exists in `HEAD` with every field of §8, and `tasks.yaml` says `done` for `<ID>` in `HEAD` | write or fix the note and the status, commit, run again |

Before T00.02 exists (task T00.01), do the gates `branch`, `clean`, `scope` and `hygiene` by hand with `git status`, `git diff --stat` and a read of the diff.

## 4. When a result is not the expected one

First work out what kind of problem it is. Then act.

| Kind | Examples | Action |
|---|---|---|
| Slip | a typo, a missing alias, formatting, a missing `@doc`, a wrong path in a test | Fix it. |
| Defect | a test fails because the code is wrong; a Verify command prints something else; an edge case crashes; a test fails once in three runs | Fix the code. Never change the test's expectation. If no test caught the problem, add one that does. A flaky test is a defect in the code or in the test: find the race or the shared state. Don't retry until it passes. |
| Wrong approach | The fix needs a different structure: state kept in the wrong process; a blocking call inside a GenServer or `:gen_statem` callback; polling where the task says events; a test that only passes with sleeps; a race. Also: the same check fails again after two fixes, or the diff spreads outside the task's scope. | Rewrite the affected part from the Specification (§5). Keep the tests that match the task. |
| Broken base | The task cannot pass because an earlier, merged task is wrong. | Record it under *Follow-ups* and tell the owner. Fix the earlier code in this branch only if this task cannot pass otherwise, and say so under *Deviations*. If the fix is not small, fix it in its own branch first (§11). |
| Plan problem | The task contradicts itself or another document, or cannot be done as written. | Set the task to `blocked`, explain why with evidence in its completion note, propose a concrete change to the plan, and stop. |

**Limits.**
1. Try at most two fixes for the same failing check.
2. If it still fails after the second, treat it as a wrong approach and rewrite the part (§5).
3. If the rewritten part fails the same check, redo the whole task once from a fresh branch (§5).
4. If that fails too, set the task to `blocked` and ask the owner.
5. Record every rewrite and redo under *Redo history* in the completion note.

**Never do any of these to make a check pass.** Each one is itself a reason to redo the task:
- weaken, delete or skip a test; loosen an assertion; add `@tag :skip`, `.skip` or `.only`;
- change an expected value to whatever the code happens to produce, unless the task file says the old value was wrong;
- raise a timeout or add a sleep to hide slowness or a race, unless the task gives the value;
- catch and ignore errors (`rescue _ -> :ok`, a bare `catch :exit, _`) to silence a failure;
- stub the module under test, or add test-only branches to production code (except the injection points the task names);
- disable a credo check, a compiler warning, a lint rule or a type check;
- write a result into the completion note or `tasks.yaml` that you did not see.

## 5. How to redo work

**Rewrite a part.**
1. Note under *Redo history* what failed and why the approach was wrong.
2. Delete that part's code instead of patching it, and write it again from the Specification. Keep the tests that match the task. Rewrite the tests that encoded the wrong approach.
3. Start again at step 3 of §2.

**Redo the whole task.**
1. Keep the old attempt for reference: `git branch -m task/<ID>-<slug> task/<ID>-<slug>-attempt1`.
2. Start fresh: `git checkout main && git checkout -b task/<ID>-<slug>`, and set the status to `in_progress` again.
3. Implement from the task file. Reuse only what you have checked is correct, for example a test file: `git checkout task/<ID>-<slug>-attempt1 -- test/…`.
4. Start again at step 1 of §2.
5. After the merge, delete the old attempt: `git branch -D task/<ID>-<slug>-attempt1`.
6. From T05.10 on, Astra's review thread continues on the new branch as the next round.

## 6. Checklist for reading the diff

Answer each question with yes, or change the code until you can:
- Does every function the Specification names exist with that name, arity, `@spec` and return shapes?
- Are the error cases in the Specification handled, with the exact error atoms, messages and exit codes?
- Are timeouts, limits, defaults and file modes the values the task gives?
- Do GenServer and `:gen_statem` callbacks avoid blocking? No sleeps, no waiting on other processes inside a callback unless the task says so, and slow work in `Task`s or in the caller as the task says.
- Is every process supervised as the task says? Does it clean up its ports, temporary files and worktrees both on exit and on a crash?
- Do external commands go through the wrappers the plan names (`Si.Git`, `Si.Checks.Command`, `Si.Runner`, `Si.OsProcess`), and never through a shell string built from outside input?
- Is every path under the Si home built with `Si.Paths`?
- Are secrets written with `Si.Paths.write_secret!/2` and never logged or printed?
- Are atoms never created from outside input?
- Are new tables, event types and settings added to `03-data-model.md` and `05-schemas-and-config.md`?
- Do the tests cover the failure paths as well as the happy path? Would each test fail if the code were wrong? (Step 7's deliberate break checks this.)
- Is the diff free of dead code, commented-out code and leftover debug output?
- Does the change touch only what the task asks for?

## 7. What "expected" means

- **Exit codes** are exact.
- **Output** means the line or value the task gives. Extra lines are fine unless the task says otherwise. Warnings (compiler, test, credo, npm, TypeScript) are never fine.
- **Tests**: every test the task lists exists and passes. 0 failures, 0 invalid. Tests are skipped only through the tags excluded by default (`:slow`, `:pi`, `:contract`, `:chaos`), and those pass when included where the task says so.
- **Flakiness**: the task's tests pass three runs in a row (`bin/task-check`). One failure in any run counts as a failure.
- **Time budgets** (`06-quality-and-testing.md` §6 and the tasks): measure three times and use the median. A miss is a defect.
- **Files**: exactly the Deliverables, plus the documentation the task says to update, the completion note and `tasks.yaml`.
- **Side effects**: tests never change this repository's branches or worktrees, the real `~/.si`, the reference repositories under `/Users/adam2/projects/pair/`, your Pi configuration, or anything outside temporary directories. No process started by a test survives it.
- **File modes** are checked with `stat -f '%Lp' <file>` on macOS (`stat -c '%a'` on Linux).

## 8. Completion note (`final_plan/status/<ID>.md`)

The note is the evidence that the loop ran. It records what you saw, not what you expected to see.

```markdown
# <ID> · <task title>

- Branch: task/<ID>-<slug>
- Summary: <what was built, 2–5 lines>
- Files: <main files added or changed>
- Tests added: <test files, with the number of tests in each>
- Acceptance criteria:
  1. <criterion, shortened> → <evidence: test file and name, or command and result>
- Verify:
  - `<command>` → <exit code and the key output line>
- After implementing:
  1. <check> → <result>
- Deliberate break: <what you changed> → <which test failed>; restored → all pass
- task-check: PASS (<n> warnings, each explained under Deviations)
- bin/ci: PASS
- Redo history: <none, or: what failed, what was rewritten or redone, and why>
- Deviations: <none, or what differs from the task and why, including every task-check WARN>
- Follow-ups: <bugs noticed elsewhere, open questions>
```

For T00.01, which comes before `bin/task-check` exists, write `task-check: gates done by hand (§3)` and list what you checked.

## 9. After the merge

1. `git checkout main && git merge --ff-only task/<ID>-<slug>`, then `bin/ci` on `main`. Expected: `PASS`. `main` now equals the branch that passed, so a failure here means a flaky test or something that depends on the environment. Run `bin/ci` once more to confirm it, then reopen the task: set it back to `in_progress` on a new branch `task/<ID>-<slug>-fix`, find the cause, and run the whole sequence again. Nothing else starts while `main` is red.
2. From T05.10 on: `bin/review-node update`. Expected: the review node reports the new `main` commit and is running on port 4041.
3. Report to the owner: the task, what changed, the results of steps 3–9 of §2, and the next task.

## 10. Milestone checkpoints

When the last task of a milestone (or of Stage A) merges, run its checkpoint from start to finish on `main`. Checkpoints marked "owner" call real models or change the machine outside the project: ask the owner first, and record their answer.

| When | Checkpoint | Expected result |
|---|---|---|
| M00 done | Start the node (`bin/si-server`), then `bin/si status`, `curl http://127.0.0.1:4040/health`, and log into the cockpit with the token. Stop the node. | `status` exits 0 with all fields; health is `{"status":"ok",…}`; the cockpit pages render after login and return 401 without it. |
| M01 done | In a temporary repository: `bin/si repo add`, `bin/si repo init --yes`; create and remove a worktree and freeze a snapshot through `mix run`. | `si/integration` exists; the profile validates; no worktree or temporary index remains. |
| M02 done | `bin/si check <temp repo>` on a passing change, then on a change with a broken test. | `PASS` with exit 0, then `FAIL (tests)` with exit 1 and a log path. |
| M03 done | `bin/si toolchain install`, `bin/si doctor`; start and stop a `si-faux` session with `bin/si session`. | All doctor checks `ok` (bridge token may warn); the session goes `idle` → `stopped`; no Pi process remains. |
| M04 done | `bin/contract-test`. | Exit 0; all scenarios pass; `git status` stays clean. |
| Stage A done (T05.10) | The Stage A demo in `07-build-order.md` §2 (owner: real Astra model). | `REVISE` with a blocking finding on the planted line and exit 1; after the fix, `APPROVE` and exit 0. |
| M05 done | `bin/si init` in a temporary home; `bin/si review` on a temporary repository (owner: real model). | Every init step prints `ok`, `done` or `action needed` with a command; the review prints a verdict with exit 0 or 1. |
| M06 done | The M06 exit demo in `07-build-order.md` §3 (owner: real builder and Astra models, and the approval policy set by the owner). | The task lands on `si/integration` and `si/task/<id>` exists. |
| M07–M14 done | The milestone's exit demo in `07-build-order.md` §3. Use `bin/si workflow check --dry-run` and the `si-faux` tests where a demo would otherwise need real models (owner for the real ones). | The exit demo's result. |

If a checkpoint fails, the milestone is not done. Find the task that broke it with `git bisect` over the milestone's merges, using the checkpoint as the test. Reopen that task, fix it with the full sequence, and run the checkpoint again before starting the next milestone.

## 11. Problems found later in merged tasks

When a check in a later task shows that an earlier, merged task is wrong, don't hide it inside the current task. Record it under *Follow-ups*, tell the owner, and fix it on its own branch `task/<earlier ID>-<slug>-fix` with the full sequence (and Astra's review from T05.10 on). The one exception is when the current task cannot pass without the fix: then fix it in the current branch and explain it under *Deviations*.
