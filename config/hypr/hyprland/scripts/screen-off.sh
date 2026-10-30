#!/usr/bin/env bash
# Screen and keyboard light off, for walking away while work keeps running.
#
# Any key or mouse movement brings the screen back (Hyprland's
# key_press_enables_dpms / mouse_move_enables_dpms); this script then puts the
# keyboard light back to the level it had, so waking needs no second step.
# Nothing here suspends or locks: running jobs carry on.
set -u
LED=asus::kbd_backlight
STATE=${XDG_RUNTIME_DIR:-/tmp}/screen-off.kbd

level=$(brightnessctl -d "$LED" get 2>/dev/null || echo "")
[ -n "$level" ] && echo "$level" > "$STATE"
brightnessctl -q -d "$LED" set 0 2>/dev/null

# Let the key that triggered this be released first, or its release event
# wakes the screen straight back up.
sleep 0.6
hyprctl dispatch 'hl.dsp.dpms("off")' >/dev/null

# Wait for the wake, then restore the light.
while sleep 1; do
    if hyprctl monitors -j 2>/dev/null | grep -q '"dpmsStatus": *true'; then
        [ -s "$STATE" ] && brightnessctl -q -d "$LED" set "$(cat "$STATE")" 2>/dev/null
        rm -f "$STATE"
        exit 0
    fi
done
