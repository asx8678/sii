---
description: Implement one specific Si task by ID
argument-hint: "<task ID, e.g. T03.06>"
---
Implement task $1 of the Si plan, following the "Implementation agent" section of AGENTS.md.

First check in `final_plan/tasks.yaml` that $1 exists, that it is `todo` (or that you are resuming it), and that every task in its `depends_on` is `done`. If not, stop and tell me what is missing. If Astra-path tasks are still open and $1 is not one of them, mention it in one line and continue, since I chose it.

If we planned $1 earlier in this session with `/si-plan`, follow that plan. Where the plan and the task file differ, the task file wins.

When the code is written, run the loop in "After writing each task" until every check in the task's After implementing section, every Verify command and `bin/task-check` show their expected results. Any other result means the task is not done yet: fix the cause or rewrite the part, and run the loop again.
