---
description: Plan a Si task before implementing it, without changing files
argument-hint: "<task ID, e.g. T06.05>"
---
Plan task $1 of the Si plan. Don't create, change or commit any files in this step. Reading, searching and read-only git commands are fine.

1. Read the task file, every document and source file it references, and the existing code it builds on. Check now every fact the task tells you to check in the Pi, Fabric or Fovea source, and cite file and line.
2. Write the plan:
   - the modules, functions (with their `@spec`s), schemas, migrations and files you will add or change;
   - the order of work, with tests first where practical;
   - each acceptance criterion and each Verify command, with the test or step that proves it;
   - edge cases, failure paths and concurrency issues that deserve a test;
   - risks, and anything in the task that looks wrong or contradicts another document, with evidence. If the task can't be done as written, say so: that is a reason to mark it `blocked`, not to redesign it.
3. End with the questions I need to answer, if any. After that I'll switch thinking to `xhigh` and run `/si-task $1` in this session.
