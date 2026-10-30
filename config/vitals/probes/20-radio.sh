#!/usr/bin/env bash
# @every 60  (link quality drifts slowly)
# Wi-Fi and Bluetooth sharing one 2.4GHz radio.
#
# Written after a mouse that "jumped" and a network that "felt slow" turned out
# to be the same problem: Wi-Fi stuck on 2.4GHz retransmitting 43% of frames,
# on the same combo chip as the Bluetooth mouse. Ping to the OWN ROUTER was
# 36ms average with 110ms peaks and zero packet loss — the retry rate was the
# only number that showed it.
#
# SPEED
# This used to sleep 2s to measure a rate, which made it the slowest probe by
# far and held up the whole display. It now stashes the counters in a state
# file and diffs against the previous run, so a rate still comes out but the
# probe returns immediately. Cumulative counters are useless on their own — a
# machine up for days averages away a currently-bad link.
set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/vitals-radio.state"

IF=$(ls /sys/class/net 2>/dev/null | grep -E '^wl' | head -1)
[ -z "${IF:-}" ] && exit 0

link=$(iw dev "$IF" link 2>/dev/null) || exit 0
echo "$link" | grep -q "Connected" || { echo "wifi=disconnected"; exit 0; }

freq=$(echo "$link" | awk '/freq:/{print $2}')
if [ -n "${freq:-}" ]; then
    echo "wifi_freq_mhz=$freq"
    # Under 3000 is 2.4GHz — the band Bluetooth also lives in.
    [ "${freq%%.*}" -lt 3000 ] && echo "wifi_band=2.4GHz_shared_with_bluetooth"
fi
echo "$link" | awk '/signal:/{print "wifi_signal_dbm="$2}'

# Retry rate as a delta against the previous invocation.
dump=$(iw dev "$IF" station dump 2>/dev/null)
r=$(echo "$dump" | awk '/tx retries/{print $3}')
p=$(echo "$dump" | awk '/tx packets/{print $3}')

if [ -n "${r:-}" ] && [ -n "${p:-}" ]; then
    if [ -r "$STATE" ]; then
        read -r pr pp < "$STATE" 2>/dev/null || { pr=0; pp=0; }
        dr=$(( r - ${pr:-0} )); dp=$(( p - ${pp:-0} ))
        # Counters reset when the interface re-associates; a negative delta
        # means that happened, so skip rather than print a nonsense figure.
        if [ "$dp" -gt 20 ] && [ "$dr" -ge 0 ]; then
            pct=$(( dr * 100 / dp ))
            echo "wifi_retry_pct=$pct"
            # Healthy is under ~5%. Past 20% the link is congested, not broken.
            [ "$pct" -gt 20 ] && echo "wifi_link_congested=yes"
        fi
    fi
    printf '%s %s\n' "$r" "$p" > "$STATE"
fi

# Bluetooth devices sharing the band. Each active one costs airtime.
if command -v bluetoothctl >/dev/null 2>&1; then
    n=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -c . || true)
    echo "bt_connected=${n:-0}"
fi

exit 0
