#!/usr/bin/env bash
# Minimize for Hyprland, which has none: a minimized window lives on the
# hidden workspace special:minimized until something brings it back.
#
#   minimize.sh               minimize the focused window
#   minimize.sh restore       bring back the most recently minimized window
#   minimize.sh restore ADDR  bring back that window (0x… address)
#
# Hyprland 0.56 with a Lua config reads `hyprctl dispatch` as Lua, hence the
# hl.dsp forms below (see hyprland/scripts/workspace_action.sh).

WS="special:minimized"

minimize() {
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$WS\", follow = false })" >/dev/null
}

restore() {
    local addr="$1" here
    if [ -z "$addr" ]; then
        # Lowest focusHistoryID = the one focused most recently.
        addr=$(hyprctl clients -j | jq -r --arg ws "$WS" \
            '[.[] | select(.workspace.name == $ws)] | sort_by(.focusHistoryID) | .[0].address // empty')
    fi
    [ -n "$addr" ] || { notify-send -a Hyprland "Nothing minimized" 2>/dev/null; exit 0; }
    here=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl dispatch "hl.dsp.window.move({ workspace = $here, window = \"address:$addr\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
}

case "${1:-}" in
    "")       minimize ;;
    restore)  restore "${2:-}" ;;
    -h|--help) sed -n 2,8p "$0" | sed 's/^# \{0,1\}//' ;;
    *)        echo "usage: $0 [restore [ADDR]]" >&2; exit 1 ;;
esac
