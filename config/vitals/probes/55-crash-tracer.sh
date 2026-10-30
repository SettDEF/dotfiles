#!/usr/bin/env bash
# @every 120  (a crash is reported within two minutes)
# Crashes, freezes, OOM kills and GPU resets, from every place they are recorded.
#
# The work is done by `vitals --crashes` (src/crashes.rs): systemd-coredump,
# the kernel log (segfaults, OOM killer, amdgpu ring timeouts / resets),
# systemd-oomd, Hyprland crash reports, and the window freezes ii-decor
# records in the compositor (~/.local/state/vitals/freezes.jsonl). This probe
# only turns that into findings; the Crashes page in the window shows each
# event with its stack trace.
#
# @option window_hours int 24 "Look back this many hours"
# @option loop_threshold int 3 "Call it a crash loop from this many crashes"
# @option ignore text "" "Apps to leave out (comma-separated, e.g. hyprsunset)"
set -uo pipefail
exec "${VITALS_BIN:-vitals}" --crashes "${VITALS_OPT_WINDOW_HOURS:-24}" --summary \
    --loop "${VITALS_OPT_LOOP_THRESHOLD:-3}" --ignore "${VITALS_OPT_IGNORE:-}"
