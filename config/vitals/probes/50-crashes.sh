#!/usr/bin/env bash
# @every 300  (crash reports accumulate, they do not flicker)
# Repeated crashes, and crash reports that leak secrets.
#
# WHY
# Two things were found by hand on 2026-08-02 that nothing was watching for:
#
#   1. WebKitWebProcess had crashed 23 times in 24 hours — every one of them a
#      `tauri dev` run of WAVR. A crash loop that restarts silently looks like
#      nothing from the desktop, but each cycle burns CPU and can leave orphans.
#
#   2. drkonqi writes the FULL PROCESS ENVIRONMENT into every crash report, and
#      the directory was mode 755. 153 of the 746 reports contained live API
#      keys in plaintext. Anything running as this user could read them.
#
# Both are cheap to check, so neither should ever have to be found by hand again.
set -uo pipefail

CRASHDIR="${XDG_CACHE_HOME:-$HOME/.cache}/drkonqi/crashes"

# --- crash rate -------------------------------------------------------------
# Count over a day rather than since boot: an uptime of weeks averages away a
# loop that started an hour ago.
if [ -d "$CRASHDIR" ]; then
    recent=$(find "$CRASHDIR" -type f -mtime -1 2>/dev/null | wc -l)
    echo "crashes_24h=$recent"

    if [ "$recent" -gt 0 ]; then
        # Which binary dominates. The filename prefix is the executable name.
        top=$(find "$CRASHDIR" -type f -mtime -1 -printf '%f\n' 2>/dev/null \
              | sed -E 's/\..*$//' | sort | uniq -c | sort -rn | head -1)
        name=$(echo "$top" | awk '{print $2}')
        n=$(echo "$top" | awk '{print $1}')
        [ -n "${name:-}" ] && echo "crash_top=${name}:${n}"

        # Ten in a day is not an accident; that is something restarting into
        # the same fault.
        if [ "$recent" -ge 10 ]; then
            echo "crash_loop_warn=${name:-unknown} crashed ${n} times in 24h"
        fi
    fi

    # --- secrets in crash reports ------------------------------------------
    # Only scan today's files: a full scan of hundreds of reports is slow, and
    # the point is to catch the leak as it happens.
    leaky=$(find "$CRASHDIR" -type f -mtime -1 2>/dev/null \
            | head -50 \
            | xargs -r grep -lE '(API_KEY|_TOKEN|_SECRET|PASSWORD)=[A-Za-z0-9_-]{8}' 2>/dev/null \
            | wc -l)
    if [ "${leaky:-0}" -gt 0 ]; then
        echo "crash_dumps_leak_secrets_critical=${leaky} recent crash report(s) contain credentials in plaintext"
    fi

    # Directory permissions: anything group- or world-readable is wrong here,
    # because the reports embed the environment.
    mode=$(stat -c %a "$CRASHDIR" 2>/dev/null)
    case "${mode:-700}" in
        700|750) ;;
        *) echo "crash_dir_world_readable_warn=$CRASHDIR is mode $mode and reports embed the full environment" ;;
    esac
fi

# --- systemd coredumps ------------------------------------------------------
# A separate store with its own retention, and the one that actually fills disk.
if command -v coredumpctl >/dev/null 2>&1; then
    n=$(coredumpctl list --since=-24h --no-pager --no-legend 2>/dev/null | grep -c . || true)
    [ "${n:-0}" -gt 0 ] && echo "coredumps_24h=$n"
fi

exit 0
