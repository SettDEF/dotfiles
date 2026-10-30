#!/usr/bin/env bash
# Hyprland lid-switch handler, gated by the quickshell "Lid" toggle (which
# mirrors its state to lid.state). When the toggle is ON:
#   lid close → turn off the internal panel if an external monitor is connected
#               (clamshell), otherwise suspend
#   lid open  → restore the internal panel
# When OFF, the lid does nothing (current default).
set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/lid.state"
INTERNAL="desc:Tianma Microelectronics Ltd. TL134ADXP03"
INTERNAL_ON="${INTERNAL},2560x1600@180.0,0x0,1.67,vrr,2"   # matches monitors.conf

enabled() { [ "$(cat "$STATE" 2>/dev/null)" = "on" ]; }

external_connected() {
    local s
    for s in /sys/class/drm/card*-*/status; do
        [ "$(cat "$s" 2>/dev/null)" = connected ] || continue
        case "$s" in *eDP*) ;; *) return 0 ;; esac   # any non-eDP output = external
    done
    return 1
}

# `hyprctl keyword` is DEAD under a Lua config — Hyprland answers "unknown
# request" to it. Both branches below used it, so closing the lid onto an
# external never blanked the panel, and OPENING the lid never restored it: the
# screen came back black and looked frozen. The live transport is the `eval`
# request carrying Lua, the same one hl.monitor takes in hyprland.lua.
#
# Type contract (verified against this build): output/mode/position/scale are
# STRINGS, vrr is an INTEGER. A wrongly typed field makes the whole call a
# silent no-op that still answers "ok", which is exactly how this stayed broken.
hypr_monitor() {
    local out
    out=$(hyprctl eval "hl.monitor({ $1 })" 2>&1)
    case "$out" in
        error*|*"unknown request"*)
            echo "lid.sh: monitor call failed: $out" >&2
            return 1 ;;
    esac
    return 0
}

case "${1:-}" in
    close)
        enabled || exit 0
        if external_connected; then
            hypr_monitor "output = \"${INTERNAL}\", disabled = true"
        else
            systemctl suspend
        fi ;;
    open)
        # Always restore the panel (harmless if it was never disabled). Retried
        # once: on resume this can run before the output is back, and a single
        # failure here leaves the user staring at a black screen with no way to
        # recover short of a VT switch.
        hypr_monitor "output = \"${INTERNAL}\", mode = \"2560x1600@180.0\", position = \"0x0\", scale = \"1.67\", vrr = 2" \
            || { sleep 1; hypr_monitor "output = \"${INTERNAL}\", mode = \"preferred\", position = \"auto\", scale = \"1.67\""; } ;;
    *)
        echo "usage: lid.sh {close|open}" >&2; exit 2 ;;
esac
