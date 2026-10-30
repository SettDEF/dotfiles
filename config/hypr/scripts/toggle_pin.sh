#!/usr/bin/env bash
# Pin the focused window to every workspace, floating it first if it is tiled -
# Hyprland's pin dispatcher silently refuses a tiled window ("does not qualify
# to be pinned"). Unpinning untiles only windows this script floated, so a
# natively floating one (a PiP popup) is left floating.
# Hyprland 0.56 is Lua-configured: `hyprctl dispatch` evaluates its argument
# inside hl.dispatch(), so the old `dispatch pin address:0x..` form is a parse
# error. The dispatchers are hl.dsp.window.pin / .float.
set -euo pipefail

state="${XDG_RUNTIME_DIR:-/tmp}/hypr-toggle-pin.addrs"
read -r addr floating pinned < <(
  hyprctl -j activewindow | python3 -c '
import json, sys
w = json.load(sys.stdin)
print(w.get("address", ""), int(bool(w.get("floating"))), int(bool(w.get("pinned"))))'
)

[ -n "$addr" ] || exit 0
touch "$state"
dsp() { hyprctl dispatch "hl.dsp.window.$1(\"address:$addr\")" >/dev/null; }

if [ "$pinned" = 1 ]; then
    dsp pin
    if grep -qxF "$addr" "$state"; then
        dsp float
        grep -vxF "$addr" "$state" > "$state.tmp" && mv "$state.tmp" "$state"
    fi
    printf 'unpinned\n'
else
    if [ "$floating" = 0 ]; then
        dsp float
        printf '%s\n' "$addr" >> "$state"
    fi
    dsp pin
    printf 'pinned\n'
fi
