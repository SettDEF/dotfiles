#!/usr/bin/env bash
# Workspace dispatcher — simple pass-through.
#
# Was an illogical-impulse "groups of 10" wrapper that mapped Super+N
# onto N within the current group of 10 workspaces (ws 11 + Super+3
# → ws 13, etc.). With unpinned workspaces and only two monitors that
# math served no purpose, so it's gone.
#
# Still keeps:
#   1. The HYPRLAND_INSTANCE_SIGNATURE rediscovery shim — under
#      uwsm/greetd Hyprland's frozen-at-exec env can hold a stale
#      signature pointing to a dead socket, making hyprctl no-op
#      silently. Without these 5 lines Super+N does nothing on first
#      keypress after login.
#   2. Passing relative arguments (r+1, -1, m+1) through verbatim,
#      since those still need to reach the dispatcher unchanged.

_rt="${XDG_RUNTIME_DIR:-/run/user/$(/usr/bin/id -u)}"
# only when our own instance's socket is gone (a stale login env): never another compositor's (loom)
if [ ! -S "$_rt/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/.socket.sock" ]; then
_sig=$(/usr/bin/ls -t "$_rt/hypr" 2>/dev/null | /usr/bin/grep -E '^[a-f0-9]+_[0-9]+_[0-9]+$' \
    | while read -r s; do [ -S "$_rt/hypr/$s/.socket.sock" ] && { echo "$s"; break; }; done)
[ -n "$_sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
fi

dispatcher="$1"
target="$2"

if [[ -z "$dispatcher" || -z "$target" || "$dispatcher" == "--help" || "$dispatcher" == "-h" ]]; then
    echo "Usage: $0 <dispatcher> <target>" >&2
    exit 1
fi

# Hyprland 0.56 with a Lua config parses `hyprctl dispatch` AS LUA:
# `dispatch workspace 3` becomes `hl.dispatch(workspace 3)` — a syntax error,
# so every workspace key silently did nothing. Emit the Lua form instead, and
# fall back to the legacy string on older Hyprland.
lua_for() {
    local d="$1" t="$2" v
    # numbers stay numbers; r+1 / m-1 / special:x stay strings
    if [[ "$t" =~ ^-?[0-9]+$ ]]; then v="$t"; else v="\"$t\""; fi
    case "$d" in
        workspace)              echo "hl.dsp.focus({ workspace = $v })" ;;
        movetoworkspace)        echo "hl.dsp.window.move({ workspace = $v })" ;;
        movetoworkspacesilent)  echo "hl.dsp.window.move({ workspace = $v, follow = false })" ;;
        togglespecialworkspace) echo "hl.dsp.workspace.toggle_special(\"$t\")" ;;
        focusmonitor)           echo "hl.dsp.focus({ monitor = $v })" ;;
        moveworkspacetomonitor) echo "hl.dsp.workspace.move({ workspace = $v })" ;;
        *)                      echo "" ;;
    esac
}

lua=$(lua_for "$dispatcher" "$target")
if [ -n "$lua" ] && hyprctl dispatch "$lua" >/dev/null 2>&1; then
    exit 0
fi
hyprctl dispatch "$dispatcher" "$target"
