# Si

Si is a control plane for coding agents, written in Elixir/OTP (Phoenix and LiveView). Pi sessions with the Fabric extension do the coding. Si decides what they work on, checks what they produce, has Astra review it on a model from a different family, and lands it. This repository builds Si from the plan in `final_plan/`: 126 tasks, each with exact deliverables, tests, acceptance criteria and verification commands. Start with `final_plan/README.md`.

## Rules for all work in this repository

These apply to anyone who writes or reviews code here, including the sessions Si itself starts.

1. **Build the plan, not a new design.** Each change implements one task file in `final_plan/tasks/`: its Deliverables and Specification, nothing more. Add dependencies only when the task lists them.
2. **Skipped topics are off limits** (`final_plan/00-overview.md`, "Skipped"): self-healing and dev mode for Si itself, worker isolation profiles, command policy, prompt-injection handling, a data egress policy, dependency and secret checks, and keeping workers alive or reattaching them across Si restarts. Don't implement them or substitutes for them.
3. **The builder approval policy is the owner's decision** (`profiles.builder.approvals`, chosen with `si init` in T05.11). Code never picks a value for it, and builders don't start while it is unset.
4. **Tests never call real models.** They use the scripted `si-faux` provider, and every Pi process a test starts has `PI_OFFLINE=1`.
5. **No secrets** in the repository, in logs or in command output. Token files are created with mode 0600.
6. **Code rules** (`final_plan/02-repo-layout.md` §2): contexts expose functions; modules have `@moduledoc`, and public functions have `@doc` and `@spec`; structs at boundaries. New code has tests.
7. **`main` stays green.** Every commit that reaches `main` passes `bin/ci`: format, compile with warnings as errors, credo strict, tests (warnings as errors), and TypeScript lint, typecheck and tests once `bridge/`, `testing/pi-faux/` or `adapter/` exist. Before T00.02 creates `bin/ci`, the task's Verify commands are the gate. The Phoenix guidelines below say to run `mix precommit`; here `bin/ci` is the check that counts.
8. **Keep the docs true.** A new event type, settings key or table goes into `final_plan/03-data-model.md` or `05-schemas-and-config.md` in the same change.
9. **Reference sources are read-only.** `/Users/adam2/projects/pair/` holds Pi 0.87.1 (`pi/`), Fabric 0.97.0 (`pi-fabric/`), Fovea 0.31.1 (`pi-fovea/`), Pair (`pi-fabric-pair/`) and the owner's audit of Pair (`todo1/`).

## Implementation agent

This section is for the coding agent the owner runs in this folder to build Si, for example Pi started here with `pi`. Sessions that Si starts (Astra, builders, critics and the rest) follow their role prompt instead; for them this section is only background. The long form of this procedure, with the completion-note template, is `final_plan/AGENT_PROMPT.md`; both say the same thing.

### At the start of every session

1. `git config user.name` and `git config user.email` must both print a value. If either is empty, stop and ask the owner. Never invent an identity.
2. If T00.01 is not done yet (there is no `mix.exs`), check the environment: Elixir 1.20 on Erlang/OTP 29, `mix phx.new --version` 1.8.x, Node 24 or newer with npm, git, a C compiler (`cc --version`; on macOS the Xcode Command Line Tools, which MuonTrap needs), and network access to hex.pm and the npm registry. If something is missing, report exactly what and stop; otherwise the next task is T00.01.
3. Finish interrupted work first: a `task/*` branch not merged into `main` (`git branch --list 'task/*' --no-merged main`), or a task marked `in_progress` in `final_plan/tasks.yaml`.

### Choosing a task

- Take the first task in `final_plan/tasks.yaml`, in file order, whose `status` is `todo` and whose `depends_on` tasks are all `done`.
- **Astra first:** while any task with `astra_path: true` is not `done`, take only those. Right after them, take T05.11.
- Do one task per request unless the owner asks for more. If the owner runs several agents at once, follow "Parallel agents" in `final_plan/AGENT_PROMPT.md`.

### Doing a task

1. Start from a clean, current `main` (`git checkout main && git pull --ff-only`), then create the branch named in the task file's header: `git checkout -b task/<ID>-<slug>`. Set the task's status to `in_progress` in `tasks.yaml` on that branch.
2. Read the whole task file, the documents it names and the code it builds on. When it says to check something in the Pi, Fabric or Fovea source, check it before you rely on it.
3. Implement exactly the Deliverables and Specification. Write the listed tests, first where practical. Commit messages start with `<ID>: `.
4. Check the work with the loop in "After writing each task" below, until every check shows its expected result.
5. Write the completion note `final_plan/status/<ID>.md` (template: `final_plan/10-after-each-task.md` §8) and set the task's status to `done` in `tasks.yaml`, in one commit. Then run `bin/task-check --final`. Expected: `RESULT: PASS`.
6. From T05.10 on, run `bin/task-review` (Astra, on the review node). On `REVISE`, treat each blocking finding as a failed check. Fix it with the loop below, commit, and run the review again. After 5 rounds without `APPROVE`, stop and ask the owner. Change nothing after the final approval.
7. Merge. If `main` moved, rebase and repeat from step 4 (and, from T05.10 on, step 6). Then run `git checkout main && git merge --ff-only task/<ID>-<slug>`, followed by `bin/ci` on `main` (expected: `PASS`). From T05.10 on, also run `bin/review-node update`. When the task completes a milestone, run its checkpoint (`10-after-each-task.md` §10).
8. Report to the owner in a few lines:
   - the task and what changed;
   - the results of `bin/task-check`, the Verify commands and the After implementing checks;
   - any redo, and why;
   - the review verdict (from T05.10 on);
   - any follow-ups;
   - the next task, with its size. If that task is size L, suggest planning it first: `/thinking max`, then `/si-plan <ID>`.

If a task is wrong, contradicts another document or can't be done as written: set it to `blocked`, explain why in its completion note with evidence (commands, output, file and line), propose a concrete change to the plan, and stop. Don't silently change the design.

### After writing each task

Work is finished only when every check shows exactly its expected result. The full rules are in `final_plan/10-after-each-task.md`. Do these in order:

1. Commit the work, then run `bin/task-check`. Expected: `RESULT: PASS`. Fix every `WARN`, or explain it in the note. (T00.01 comes before `bin/task-check` exists, so do its gates by hand as its task file says.)
2. Run every command in the task's **Verify** section. Run a multi-line block as one shell command. Expected: the result written next to each command; where none is written, exit 0 with no error output.
3. Run every check in the task's **After implementing** section. Expected: the result stated for each one.
4. For each acceptance criterion, name the test (file and name) or the command output that proves it. A criterion without evidence is not met.
5. Read `git diff main...HEAD` against the Specification (checklist: `10-after-each-task.md` §6). Then break the code on purpose once (flip a condition a test should guard), confirm that a test fails, and restore it.

Any other result means the task goes back:
- A slip or a defect: fix the code, and add a test if none caught it. Never change what a test expects, never skip or weaken a test, never raise a timeout or add a sleep, never silence an error or a warning.
- A wrong approach, or the same check failing again after two fixes: rewrite that part from the Specification. The task's **Redo if** list names the typical cases.
- If the rewritten part fails the same check: redo the whole task once from a fresh branch (`10-after-each-task.md` §5).
- If that fails too: set the task to `blocked` and ask the owner.

After every change, run the loop again from step 1. Record what you saw, not what you expected to see, and every redo, in the completion note.

### Running commands

- The bash tool has no default timeout. Give commands that can hang one: about 900 s for dependency installs, builds and full test runs, and 60 s for single checks.
- Start servers in the background with their output in a log file under `tmp/` (git ignores it), and print the PID: `mkdir -p tmp; bin/si-server > tmp/si-server.log 2>&1 & echo $!`. Stop exactly that PID when you are done (`kill <pid>`). Never use `pkill`, `killall` or name patterns, because other projects on this machine run their own Phoenix servers and BEAM nodes. Before starting a server, check that its port is free, for example `lsof -nP -iTCP:4040 -sTCP:LISTEN`.
- The repository's remote is `origin` (`git@github.com:asx8678/si.git`). Pull with `--ff-only`. Push only when the owner asks, and never force-push.
- Don't pipe `mix` or `elixir` output into `head`: closing the pipe early makes the VM crash and write an `erl_crash.dump`. Redirect to a file under `tmp/` and read that instead.
- Run nothing interactive: no `iex`, no editors, no `git rebase -i`, no `git add -p`. Pipe `yes` into generators that prompt, pass `-m` to `git commit`, and use `GIT_EDITOR=true git rebase --continue`.
- Change files only in this folder, in the Si homes (`~/.si`, plus `~/.si-review` for the review node from T05.10 on), in temporary directories that tests create, and, for parallel agents, in their worktrees under `/Users/adam2/projects/skynet-work/`.

### Stop and ask the owner when

- a task is blocked, or Astra hasn't approved after 5 rounds;
- a decision belongs to the owner: the builder approval policy, which models Si uses (Astra on the review node must run on a model from a different family than yours), or which repositories to use for evals;
- a step calls real models or costs money, such as the manual check in T05.10, `si init --check-models` or eval runs in T07.04. Ask first, then record the output in the completion note;
- a step would change something on the owner's machine outside the project and the Si homes: `si bridge install --apply` (T04.12), `bin/si-install` (T11.12), pushing to a real remote, or opening a real pull request. Tests use fakes for all of these;
- credentials, network access or tool installation fail in a way you can't fix inside the repository.
