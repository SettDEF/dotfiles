#!/usr/bin/env bash
# Suspend on idle — but only once the machine is genuinely idle.
#
#   idle-suspend.sh [run]     evaluate guards; suspend now, or defer and retry
#   idle-suspend.sh cancel    abort a pending deferred suspend (user came back)
#   idle-suspend.sh status    print what the guards currently say, change nothing
#
# WHY THIS EXISTS
# hypridle measures INPUT inactivity only. A render, build, download or film
# needs no mouse movement, so its timeout listener would suspend the machine in
# the middle of real work.
#
# WHY IT DEFERS RATHER THAN SKIPS
# hypridle fires on-timeout exactly ONCE per idle period. A script that simply
# exits when busy means the machine then never suspends until you touch input
# and go idle all over again — so a film at the 15-minute mark would keep the
# laptop awake all night. Instead, when a guard trips we keep polling in the
# background and suspend as soon as the machine falls quiet.
#
# Pair it in hypridle.conf with on-resume so returning to the keyboard aborts a
# pending deferral:
#   listener {
#       timeout    = 900
#       on-timeout = /home/caesar/.config/hypr/hyprland/scripts/idle-suspend.sh
#       on-resume  = /home/caesar/.config/hypr/hyprland/scripts/idle-suspend.sh cancel
#   }
#
# Every decision is logged (journal tag: idle-suspend).
set -uo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/idle-suspend.conf"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNDIR/idle-suspend.defer.pid"
NETSTAMP="$RUNDIR/idle-suspend.net"

# ── Defaults (override in idle-suspend.conf) ──────────────────────────────
GUARD_AUDIO=1           # something is actually playing through a sink
GUARD_LOAD=1            # sustained CPU work
GUARD_INHIBITORS=1      # a block-mode sleep/idle inhibitor is held
GUARD_PROCESSES=1       # a named long-running job is present
GUARD_NETWORK=1         # a big transfer is in flight

# 1-min load average counting as "working". 32 threads here, so 6.0 is ~19%
# busy — clear of the ~1-2 idle baseline, low enough to catch a film or build.
LOAD_THRESHOLD=6.0

# Extended regex matched against process names.
BUSY_PROCESSES='ffmpeg|makepkg|cargo|rustc|cc1plus|ld\.lld|rsync|pacman|paru|yay|dd|handbrake|obs|blender|kdenlive|shotcut|qbittorrent|transmission|steam(cmd)?|wget|curl'

# Sustained throughput (KB/s, summed over real interfaces) counting as busy.
NET_THRESHOLD_KBPS=200

RECHECK_INTERVAL=60     # seconds between re-checks while deferring
MAX_DEFER_SECONDS=0     # 0 = defer indefinitely; else suspend anyway after this

# Below this battery %, ignore every guard and suspend — protecting the machine
# from dying mid-task beats keeping it awake. 0 disables.
BATTERY_OVERRIDE_PCT=10

# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

log() { logger -t idle-suspend "$*" 2>/dev/null; }

# ── Guards. Each echoes a reason and returns 0 when it BLOCKS suspend. ─────

guard_battery_override() {   # returns 0 when we must suspend regardless
    [ "${BATTERY_OVERRIDE_PCT:-0}" -gt 0 ] || return 1
    local cap ac
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
    ac=$(cat /sys/class/power_supply/AC0/online 2>/dev/null || echo 1)
    [ "$ac" = "0" ] && [ "$cap" -le "$BATTERY_OVERRIDE_PCT" ]
}

guard_audio() {
    [ "${GUARD_AUDIO:-0}" = "1" ] || return 1
    # RUNNING means a stream is feeding the sink right now. IDLE/SUSPENDED
    # sinks do not count, so merely having speakers connected is not enough.
    pactl list sinks short 2>/dev/null | grep -q "RUNNING" && { echo "audio is playing"; return 0; }
    return 1
}

guard_load() {
    [ "${GUARD_LOAD:-0}" = "1" ] || return 1
    local l; l=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
    awk -v l="$l" -v t="$LOAD_THRESHOLD" 'BEGIN{exit !(l > t)}' \
        && { echo "load $l > $LOAD_THRESHOLD"; return 0; }
    return 1
}

guard_inhibitors() {
    [ "${GUARD_INHIBITORS:-0}" = "1" ] || return 1
    # Only MODE=block counts. NetworkManager/UPower/rtkit/hypridle register
    # MODE=delay, which merely postpones the handoff a few seconds; treating
    # those as "do not sleep" would mean never suspending at all.
    systemd-inhibit --list --no-pager 2>/dev/null \
        | awk '$0 ~ /block/ && $0 ~ /(sleep|idle)/ {f=1} END{exit !f}' \
        && { echo "a block-mode sleep inhibitor is held"; return 0; }
    return 1
}

guard_processes() {
    [ "${GUARD_PROCESSES:-0}" = "1" ] || return 1
    local hit
    # Match on the process NAME only (not full argv) so this script's own
    # command line cannot match its own pattern.
    hit=$(ps -eo comm= 2>/dev/null | grep -aExm1 "$BUSY_PROCESSES" || true)
    [ -n "$hit" ] && { echo "process '$hit' is running"; return 0; }
    return 1
}

guard_network() {
    [ "${GUARD_NETWORK:-0}" = "1" ] || return 1
    local now bytes prev_t prev_b dt db kbps
    now=$(date +%s)
    bytes=$(cat /sys/class/net/[ew]*/statistics/rx_bytes /sys/class/net/[ew]*/statistics/tx_bytes 2>/dev/null \
            | awk '{s+=$1} END{print s+0}')
    if [ -r "$NETSTAMP" ]; then
        read -r prev_t prev_b < "$NETSTAMP" 2>/dev/null || { prev_t=0; prev_b=0; }
        dt=$(( now - prev_t )); db=$(( bytes - prev_b ))
        printf '%s %s\n' "$now" "$bytes" > "$NETSTAMP"
        if [ "$dt" -gt 0 ] && [ "$db" -gt 0 ]; then
            kbps=$(( db / dt / 1024 ))
            [ "$kbps" -gt "$NET_THRESHOLD_KBPS" ] && { echo "network ${kbps}KB/s > ${NET_THRESHOLD_KBPS}KB/s"; return 0; }
        fi
    else
        # First sample has no baseline to compare against; record and allow.
        printf '%s %s\n' "$now" "$bytes" > "$NETSTAMP"
    fi
    return 1
}

# Echoes the first blocking reason, or nothing when clear.
blocking_reason() {
    local r
    for g in guard_audio guard_load guard_inhibitors guard_processes guard_network; do
        r=$("$g") && { echo "$r"; return 0; }
    done
    return 1
}

do_suspend() {
    log "suspending ($1)"
    rm -f "$PIDFILE"
    systemctl suspend || loginctl suspend
}

cancel_pending() {
    if [ -r "$PIDFILE" ]; then
        local p; p=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
            kill "$p" 2>/dev/null
            log "deferred suspend cancelled (user active)"
        fi
        rm -f "$PIDFILE"
    fi
}

# Background poller: wait for the machine to fall quiet, then suspend.
defer_loop() {
    local waited=0 reason
    while true; do
        sleep "$RECHECK_INTERVAL"
        waited=$(( waited + RECHECK_INTERVAL ))

        if guard_battery_override; then
            do_suspend "battery <= ${BATTERY_OVERRIDE_PCT}%, overriding guards"
            return
        fi
        if ! reason=$(blocking_reason); then
            do_suspend "machine went quiet after ${waited}s"
            return
        fi
        if [ "${MAX_DEFER_SECONDS:-0}" -gt 0 ] && [ "$waited" -ge "$MAX_DEFER_SECONDS" ]; then
            do_suspend "max defer ${MAX_DEFER_SECONDS}s reached (last reason: $reason)"
            return
        fi
        log "still deferring after ${waited}s: $reason"
    done
}

case "${1:-run}" in
    cancel)
        cancel_pending
        ;;
    status)
        if r=$(blocking_reason); then echo "BLOCKED: $r"; else echo "CLEAR: would suspend"; fi
        [ -r "$PIDFILE" ] && echo "deferral pending (pid $(cat "$PIDFILE" 2>/dev/null))"
        ;;
    run|*)
        cancel_pending          # never run two deferrals at once
        guard_network >/dev/null || true   # prime the throughput baseline
        if guard_battery_override; then
            do_suspend "battery <= ${BATTERY_OVERRIDE_PCT}%, overriding guards"
            exit 0
        fi
        if reason=$(blocking_reason); then
            log "deferring: $reason (re-checking every ${RECHECK_INTERVAL}s)"
            defer_loop &
            echo $! > "$PIDFILE"
        else
            do_suspend "idle, no guards tripped"
        fi
        ;;
esac
