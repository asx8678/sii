---
description: Implement the next Si task (or the next N) from final_plan
argument-hint: "[number of tasks, default 1]"
---
Implement the next ${1:-1} task(s) of the Si plan, following the "Implementation agent" section of AGENTS.md.

- Do the session checks from that section first, and finish an interrupted task before starting a new one.
- Say in one line which task you picked and why. Then take it through every step: branch, implement, then the loop in "After writing each task" (`bin/task-check`, Verify, the task's After implementing checks, acceptance evidence, the diff read with one deliberate break). After that come the completion note and status, `bin/task-check --final`, the Astra review from T05.10 on, and the merge.
- A task is finished only when every check has shown its expected result. If a result is different, fix or rewrite the work and run the loop again. Never change what a test expects to make it pass.
- After each task, give the short report AGENTS.md describes, including any redo. Stop early if a task is blocked or needs my decision; don't skip ahead to another task.
