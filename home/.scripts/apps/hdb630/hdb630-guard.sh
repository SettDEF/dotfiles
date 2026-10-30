#!/usr/bin/env bash
# Keeps the HDB 630's hardware output level pinned, and goes silent across
# card reconfiguration.
#
# Why: the headset's ALSA "PCM" control has sixteen steps of 3 dB. Step 15 is
# 0 dB; a normal listening level here is step 12 (-9 dB). Anything that resets
# that control — a replug, a profile switch, a reconfiguration — leaves up to
# 9 dB of headroom ABOVE where you listen, which is what turns a burst of
# noise into a painful one. Pinning the ceiling means that headroom does not
# exist, whatever produced the noise.
#
# Volume itself moves to software (see the wireplumber rule), so this control
# is a ceiling, not a knob. Raise it with HDB630_PIN if you need more volume.
set -u

CARD=H630
CTL=PCM
PIN=${HDB630_PIN:-12}
LOG=${XDG_STATE_HOME:-$HOME/.local/state}/hdb630-guard.log
mkdir -p "$(dirname "$LOG")"

log()     { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
present() { amixer -c "$CARD" sget "$CTL" >/dev/null 2>&1; }
step()    { amixer -c "$CARD" sget "$CTL" 2>/dev/null \
              | sed -n 's/.*Playback \([0-9]\{1,\}\) \[.*/\1/p' | head -1; }
setstep() { amixer -q -c "$CARD" sset "$CTL" "$1" 2>/dev/null; }
mute()    { amixer -q -c "$CARD" sset "$CTL" off 2>/dev/null; }
unmute()  { amixer -q -c "$CARD" sset "$CTL" on 2>/dev/null; }
hdbcard() { pactl list cards short 2>/dev/null | awk '/HDB_630/{print $1; exit}'; }

clamp() {
    present || return 0
    local s; s=$(step)
    [ -n "$s" ] || return 0
    if [ "$s" -gt "$PIN" ]; then
        log "clamped step $s -> $PIN ($(( (s - PIN) * 3 )) dB of headroom removed)"
        setstep "$PIN"
    fi
}

# The blast happens across reconfiguration, so be muted while it happens.
reconfigure() {
    present || return 0
    mute
    setstep "$PIN"
    sleep 0.5
    unmute
    log "card reconfigured — muted through it, restored at step $PIN"
}

# ── Pulse-layer desync ───────────────────────────────────────────────────
# Restarting WirePlumber leaves pipewire-pulse with a stale device list: the
# sink exists natively (wpctl sees it, audio plays) but pactl cannot see it,
# so anything using the Pulse API — including the shell's audio panel — shows
# the wrong device and cannot switch to it.
#
# The cure, restarting pipewire-pulse, SEVERS EVERY LIVE STREAM and browsers
# do not reconnect one that was cut. So this only ever acts while nothing is
# playing, which means the desync heals itself at a moment that costs nothing.
LAST_RESYNC=0
RESYNC_COOLDOWN=120

native_sinks() { wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -c "HDB 630"; }
pulse_sinks()  { pactl list sinks short 2>/dev/null | grep -c Sonova; }
streams_live() { [ "$(pactl list sink-inputs short 2>/dev/null | wc -l)" -gt 1 ]; }

check_desync() {
    [ "$(native_sinks)" -gt 0 ] || return 0
    [ "$(pulse_sinks)" -eq 0 ] || return 0
    if streams_live; then
        log "pulse layer is out of sync, but audio is playing — waiting"
        return 0
    fi
    local now; now=$(date +%s)
    [ $((now - LAST_RESYNC)) -ge "$RESYNC_COOLDOWN" ] || return 0
    LAST_RESYNC=$now
    log "pulse layer out of sync and nothing playing — restarting pipewire-pulse"
    systemctl --user restart pipewire-pulse
}

log "guard started (pin=$PIN)"
clamp
check_desync

pactl subscribe 2>/dev/null | while read -r ev; do
    case "$ev" in
        *"on card"*)
            idx=${ev##*#}
            hdb=$(hdbcard)
            if [ -n "$hdb" ] && [ "$idx" = "$hdb" ]; then reconfigure; else clamp; fi
            ;;
        *"on sink"*|*"on server"*)
            clamp
            check_desync
            ;;
    esac
done
