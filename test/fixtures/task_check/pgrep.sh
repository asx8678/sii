#!/usr/bin/env bash
if [[ ${TC_PROCESS_LEAK:-0} == 1 ]]; then echo '12345 fake_pi.mjs'; exit 0; fi
if [[ ${TC_PROCESS_ERROR:-0} == 1 ]]; then exit 2; fi
exit 1
