---
description: Run the after-task checks on the current task branch and fix what doesn't match
argument-hint: "[task ID, default: from the branch name]"
---
Run the after-task checks for task ${1:-named by the current branch (task/<ID>-…)}, as `final_plan/10-after-each-task.md` §2 describes. Don't start another task.

1. Make sure the work is committed, then run `bin/task-check`.
2. Run every command in the task's Verify section, then every check in its After implementing section.
3. For each acceptance criterion, find the evidence (a test or a command output).
4. Read `git diff main...HEAD` against the Specification with the checklist in §6. Break the code on purpose once and confirm that a test fails, then restore it.

Report a table with one row per check: check · expected · actual · PASS or FAIL.

Then, for every FAIL:
- fix it the way §4 says, or rewrite the part (the task's **Redo if** list names the typical cases);
- commit, and run all the checks again from step 1;
- keep going until every row is PASS, or the limits in §4 are reached; in that case, set the task to `blocked` and tell me why.

Never make a check pass by changing what it expects.
