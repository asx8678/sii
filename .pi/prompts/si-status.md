---
description: Show progress on the Si plan (read-only)
---
Report progress on the Si plan. Don't change anything.

- If T00.01 is not done yet (there is no `mix.exs`), say so: nothing is built, and the next task is T00.01.
- From `final_plan/tasks.yaml`: the number of tasks per status, and Astra-path progress (done out of 40).
- Unfinished work: `task/*` branches not merged into `main` (`git branch --list 'task/*' --no-merged main`), tasks marked `in_progress`, and `blocked` tasks with the reason from their completion notes.
- Git: the current branch, whether the working tree is clean, and the last 5 commits on `main`.
- The next 3 tasks the selection rule in AGENTS.md would pick, with ID, size and title. Flag size L tasks, which are worth planning first with `/si-plan` at `max` thinking.
- From T05.10 on: whether the review node is running (`bin/review-node status`).

Keep it under 25 lines.
