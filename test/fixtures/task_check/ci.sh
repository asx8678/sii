#!/usr/bin/env bash
set -eu
printf '\n==> format\n==> compile\n==> credo\n==> test\n'
if [[ ${TC_CI_FAIL:-0} == 1 ]]; then
  awk 'BEGIN {for (i=1;i<=35;i++) print "log-line-" i}'
  exit 2
fi
printf 'PASS\n'
