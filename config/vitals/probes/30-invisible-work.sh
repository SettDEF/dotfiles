#!/usr/bin/env bash
# @every 60  (an invisible burner is worth catching within a minute)
# Work happening where nobody can see it.
#
# Written after TWO invisible copies of a DAW burned ~22 CPU cores on virtual
# framebuffers for nine hours. The machine was hot, loud, slow and draining its
# battery at 82W, and every diagnosis pointed at fan curves and power profiles —
# because nothing showed that a third of the CPU was rendering to displays that
# do not exist.
#
# The project's own cleanup script says it best: "Nothing was misconfigured.
# The only bug was that nobody cleaned up."
#
# NOTE: orphan detection deliberately lives in the Rust rules engine, not here.
# A shell probe can only see CUMULATIVE CPU time, which flags every
# long-running session process (qs, wezterm) as a false positive. The engine
# samples a RATE, which is the number that actually distinguishes "leaked and
# spinning" from "alive since login".
set -uo pipefail

# Virtual framebuffers, and how long they have been up. Xvfb is legitimate for
# headless testing; an old one usually means a test that never exited.
n=0
while read -r pid etime cmd; do
    [ -z "${pid:-}" ] && continue
    n=$(( n + 1 ))
    disp=$(echo "$cmd" | grep -oE ':[0-9]+' | head -1)
    echo "xvfb_${n}_display=${disp:-?}"
    echo "xvfb_${n}_uptime=$etime"
    # Anything past an hour is very unlikely to be an active test run.
    case "$etime" in
        *:*:*) echo "xvfb_${n}_stale=yes" ;;
    esac
done < <(ps -eo pid=,etime=,args= 2>/dev/null | grep '[X]vfb' | awk '{print $1, $2, substr($0, index($0,$3))}')
echo "xvfb_count=$n"

# Processes on a virtual display that have accumulated real CPU time.
# /proc/<pid>/environ is only readable for our own processes, so this sees the
# user's own work — which is exactly where leaked test instances live.
busy=0
for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    # Check CPU time FIRST. Reading /proc/<pid>/environ for every process was
    # costing ~1s per run on a busy machine; the stat read is far cheaper and
    # rejects almost everything, so environ is only touched for the handful of
    # processes that have actually done work.
    read -r _ _ _ _ _ _ _ _ _ _ _ _ _ ut st _ < "$p/stat" 2>/dev/null || continue
    total=$(( ${ut:-0} + ${st:-0} ))
    [ "$total" -lt 6000 ] && continue   # under ~60 CPU-seconds: not interesting

    d=$(tr '\0' '\n' < "$p/environ" 2>/dev/null | grep -m1 '^DISPLAY=' | cut -d= -f2) || continue
    case "$d" in
        :[2-9]*|:[0-9][0-9]*) ;;
        *) continue ;;
    esac
    busy=$(( busy + 1 ))
    echo "hidden_${busy}_pid=$pid"
    echo "hidden_${busy}_comm=$(tr -d '\0' < "$p/comm" 2>/dev/null)"
    echo "hidden_${busy}_display=$d"
    echo "hidden_${busy}_cpu_seconds=$(( total / 100 ))"
done 2>/dev/null
echo "hidden_busy_count=$busy"

exit 0
