#!/usr/bin/env bash
# @every 120  (idle package power is a trend, not a reading)
# Why the package draws what it draws when nothing is running.
#
# WHY
# On 2026-08-02 this machine sat at 69-71 C and 31 W with 5% CPU busy and 11%
# GPU busy, fans at 4600 rpm. Every per-process view said the machine was idle,
# because by utilisation it WAS idle. Hunting it by hand took an hour and went
# through three wrong theories, because the useful numbers are not utilisation
# at all — they are how deeply the cores idle, how low they are allowed to
# clock, and how often something drags them back out.
#
# The three that actually explain it:
#
#   1. scaling_min_freq — amd-pstate-epp defaults the floor to
#      amd_pstate_lowest_nonlinear_freq, which is 2000 MHz here while the
#      hardware can reach 625 MHz. 32 threads that may never drop below 2 GHz
#      cost real watts.
#   2. C-state residency — cores parked in C3 draw almost nothing. Cores
#      bouncing in C1 draw a lot. Utilisation cannot tell these apart.
#   3. IPI rate — function-call and rescheduling interrupts wake idle cores.
#      65,000/s was measured during the hot period against 17,000/s after.
set -uo pipefail

CPUFREQ=/sys/devices/system/cpu/cpu0/cpufreq

# --- frequency floor --------------------------------------------------------
if [ -r "$CPUFREQ/scaling_min_freq" ] && [ -r "$CPUFREQ/cpuinfo_min_freq" ]; then
    smin=$(cat "$CPUFREQ/scaling_min_freq")
    hwmin=$(cat "$CPUFREQ/cpuinfo_min_freq")
    echo "cpu_floor_mhz=$(( smin / 1000 ))"
    echo "cpu_hw_min_mhz=$(( hwmin / 1000 ))"
    # Only worth mentioning when there is real headroom below the floor.
    if [ "$smin" -gt $(( hwmin * 2 )) ]; then
        echo "cpu_floor_raised=the floor is $(( smin / 1000 )) MHz but the hardware can reach $(( hwmin / 1000 )) MHz"
    fi
fi

# Average clock across all threads. High average at low load is the symptom
# that a raised floor produces.
if [ -r /proc/cpuinfo ]; then
    avg=$(awk '/^cpu MHz/{s+=$4; n++} END{if(n) printf "%d", s/n}' /proc/cpuinfo)
    [ -n "${avg:-}" ] && echo "cpu_avg_mhz=$avg"
fi

# --- one sampling window for everything below --------------------------------
# All three measurements below are deltas. Taken separately they cost three
# sleeps, which made this the slowest probe in the set at 3.0s — slower than
# the display refresh it feeds. Everything is now read before one sleep and
# again after it, so the whole probe costs ~0.55s.
CS=/sys/devices/system/cpu/cpu0/cpuidle

# CAL (function call) and RES (rescheduling) are the interrupts that wake idle
# cores. Match with leading whitespace tolerated — /proc/interrupts right-aligns
# the label column, so an anchored ^CAL never matched and this silently read 0.
read_ipi() {
    awk '$1 ~ /^(CAL|RES):$/ {s=0; for(i=2;i<=NF;i++) if ($i ~ /^[0-9]+$/) s+=$i; t+=s} END{print t+0}' \
        /proc/interrupts
}
read_busy() {
    awk '/^cpu /{i=$5; t=0; for(x=2;x<=NF;x++) t+=$x; print t" "i}' /proc/stat
}

declare -A t0
for s in "$CS"/state*/; do
    t0["$(cat "$s/name" 2>/dev/null)"]=$(cat "$s/time" 2>/dev/null || echo 0)
done
ipi_a=$(read_ipi)
busy_a=$(read_busy)

# 0.5s, not 1s. A full second made this the whole probe budget on its own and
# pushed a snapshot from 0.28s to 1.07s. Half a second is plenty for rates that
# are in the thousands per second, and the percentages just scale.
sleep 0.5

ipi_b=$(read_ipi)
busy_b=$(read_busy)

# --- C-state residency ------------------------------------------------------
if [ -d "$CS" ]; then
    deep=0; shallow=0
    for s in "$CS"/state*/; do
        n=$(cat "$s/name" 2>/dev/null) || continue
        now=$(cat "$s/time" 2>/dev/null || echo 0)
        d=$(( now - ${t0[$n]:-0} ))
        # Microseconds in this state over the 0.5s window -> percent.
        pct=$(( d / 5000 ))
        case "$n" in
            C3*|C6*|C8*) deep=$(( deep + pct )) ;;
            POLL|C1*|C2*) shallow=$(( shallow + pct )) ;;
        esac
    done
    echo "cstate_deep_pct=$deep"
    echo "cstate_shallow_pct=$shallow"
    # Cores that idle mostly shallow burn power for nothing.
    if [ "$deep" -lt 40 ] && [ "$shallow" -gt 30 ]; then
        echo "cores_not_idling_deep=cores spent ${deep}% in deep idle and ${shallow}% in shallow idle"
    fi
fi

# --- interrupt pressure -----------------------------------------------------
if [ -n "${ipi_a:-}" ] && [ -n "${ipi_b:-}" ]; then
    # Doubled: the window is half a second.
    rate=$(( (ipi_b - ipi_a) * 2 ))
    echo "ipi_per_sec=$rate"
    # Baseline on this machine is ~5-18k/s; 40k+ was only ever seen while hot.
    [ "$rate" -gt 40000 ] && echo "ipi_storm_warn=${rate} inter-processor interrupts per second are keeping cores awake"
fi

# --- efficiency verdict -----------------------------------------------------
# Package watts against actual utilisation. This is the number that would have
# pointed straight at the problem instead of at the process list.
t1=${busy_a% *}; i1=${busy_a#* }
t2=${busy_b% *}; i2=${busy_b#* }
if [ "$t2" -gt "$t1" ]; then
    used=$(( 100 - (i2 - i1) * 100 / (t2 - t1) ))
    echo "cpu_busy_pct=$used"
    w=$(cat /sys/class/hwmon/hwmon*/power1_average 2>/dev/null | head -1)
    if [ -n "${w:-}" ] && [ "$w" -gt 0 ] 2>/dev/null; then
        watts=$(( w / 1000000 ))
        echo "package_w=$watts"
        # Over 25 W while under 15% busy means the watts are not going into work.
        if [ "$watts" -gt 25 ] && [ "$used" -lt 15 ]; then
            echo "idle_power_high_warn=${watts} W drawn at only ${used}% CPU busy"
        fi
    fi
fi

exit 0
