---
description: Redo a Si task whose result is not what it should be
argument-hint: "<task ID> [what is wrong]"
---
Task $1 is not right. ${@:2}

Redo it as `final_plan/10-after-each-task.md` §5 describes:

1. Find what differs from the task file: run its Verify commands and After implementing checks, and read its Specification and Redo if list against the code. Tell me in a few lines what is wrong and why.
2. If only one part is wrong, rewrite that part from the Specification; don't patch around it.
3. If the approach itself is wrong, or a rewrite already failed:
   - keep the old attempt as `task/<ID>-<slug>-attempt1`;
   - start a fresh branch from `main`, and implement the task again from the task file.
4. If $1 is already merged, do the redo on the branch `task/<ID>-<slug>-fix`, and tell me which later tasks build on the code you change.
5. Run the whole after-task loop until every check shows its expected result, then the completion note, the review from T05.10 on, and the merge.

Record the redo under "Redo history" in the completion note.
