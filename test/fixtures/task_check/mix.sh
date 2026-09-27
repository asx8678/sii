#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$TASK_CHECK_TRACE"
case "$1" in
  si.doc_check)
    if [[ ${TC_DOCS_FAIL:-0} == 1 ]]; then echo 'Fixture.Module.value/0: missing @spec'; exit 1; fi
    echo 'ok: 1 modules, 1 functions'
    ;;
  test)
    if [[ ${TC_REF_LEAK:-0} == 1 ]]; then git branch fixture-leak; fi
    if [[ ${TC_WORKTREE_LEAK:-0} == 1 ]]; then git worktree add --detach tmp/leaked-worktree HEAD >/dev/null 2>&1; fi
    if [[ ${TC_TEST_FAIL:-0} == 1 ]]; then echo 'fixture test failure'; exit 2; fi
    echo 'fixture tests passed'
    ;;
  *) echo 'unexpected fixture mix invocation' >&2; exit 9 ;;
esac
