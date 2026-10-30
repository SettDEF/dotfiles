#!/usr/bin/env bash
# @every 300  (suspend history changes only around a suspend)
# What woke the machine, and how well it stays asleep.
#
# Written after a keyboard folio woke this laptop within 4-7 SECONDS of every
# suspend. The trigger was visible in the log the whole time — an
# `asus_wmi: Unknown key code 0xe9` landing in the same second as each
# `PM: suspend exit` — but nothing surfaced it, so it read as "my laptop wakes
# up by itself" for days.
#
# Reports sleep quality and which devices are permitted to wake.
#
# ACCURACY
# This used to judge the LAST sleep alone, which produced a standing warning on
# a machine that was sleeping fine: waking the laptop, immediately re-suspending
# it, then cancelling that by hand looks identical to a spurious wake. Over
# three days the real record was 5h, 6h and 1h sleeps with one 18s outlier the
# user caused themselves. One short sleep is noise; a PATTERN of them is the
# bug the probe was written for, so it now needs several before it complains.
set -uo pipefail

# Pair up suspend entries and exits over the recent history. Read once — this
# journal query is by far the most expensive thing in the probe.
#
# NOT `journalctl -k`: that implies --boot, so it silently reduces a 7-day
# window to the current boot. On a laptop that reboots often this reported two
# sleep cycles where there had been six, which is exactly the sample size the
# pattern check needs. Filtering by transport keeps it to kernel messages
# without pinning it to one boot.
pairs=$(journalctl _TRANSPORT=kernel -o short-unix --no-pager --since=-7d 2>/dev/null \
        | grep -E "PM: suspend (entry|exit)" \
        | awk '{t=$1; sub(/\..*/,"",t); if (/entry/) e=t; else if (e!="") {print t-e; e=""}}')

if [ -n "${pairs:-}" ]; then
    last=$(echo "$pairs" | tail -1)
    echo "last_sleep_s=$last"

    total=$(echo "$pairs" | grep -c .)
    # Only the recent ones matter; a fault fixed last week should stop warning.
    short=$(echo "$pairs" | tail -8 | awk '$1 < 120' | grep -c . || true)
    recent=$(echo "$pairs" | tail -8 | grep -c .)
    echo "sleep_cycles_7d=$total"
    echo "sleep_short_recent=${short:-0}/${recent:-0}"

    # Two or more short sleeps out of the last eight is a pattern worth naming.
    # A single one is almost always the user re-suspending and changing mind.
    if [ "${short:-0}" -ge 2 ]; then
        echo "sleep_was_cut_short=${short} of the last ${recent} suspends ended within 2 minutes"
    fi

    # Longest recent sleep is the useful counter-evidence: if the machine can
    # stay down for hours, wake sources are not systemically broken.
    longest=$(echo "$pairs" | tail -8 | sort -rn | head -1)
    [ -n "${longest:-}" ] && echo "sleep_longest_recent_s=$longest"
fi

# The dominant wakeup source by event count. This is what actually identifies a
# chatty device — the USB wakeup flags below only say what is PERMITTED to wake
# the machine, not what has been doing it.
best_n=""; best_c=0
for f in /sys/class/wakeup/*/; do
    c=$(cat "$f/event_count" 2>/dev/null) || continue
    [ "${c:-0}" -gt "$best_c" ] 2>/dev/null || continue
    best_c=$c; best_n=$(cat "$f/name" 2>/dev/null)
done
if [ -n "${best_n:-}" ] && [ "$best_c" -gt 0 ]; then
    echo "wake_top_source=${best_n}"
    echo "wake_top_events=${best_c}"
fi

# Devices allowed to break sleep. When this list is empty only the power button
# works — worth knowing before wondering why a keypress does nothing.
n=0
for d in /sys/bus/usb/devices/*/; do
    [ -r "$d/power/wakeup" ] || continue
    [ "$(cat "$d/power/wakeup" 2>/dev/null)" = "enabled" ] || continue
    n=$(( n + 1 ))
    name=$(cat "$d/product" 2>/dev/null | tr ' ' '_')
    echo "wake_usb_${n}=${name:-$(basename "$d")}"
done
echo "wake_enabled_count=$n"

# Spurious-wake fingerprints seen since boot.
c=$(journalctl -k --no-pager 2>/dev/null | grep -c "Unknown key code" || true)
[ "${c:-0}" -gt 0 ] && echo "asus_unknown_keycodes=$c"

exit 0
