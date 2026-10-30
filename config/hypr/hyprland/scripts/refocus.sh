#!/usr/bin/env bash
#
# refocus.sh — re-assert keyboard focus to the active window.
#
# Hyprland and Quickshell config reloads churn layer-shell surfaces, which
# can leave keyboard focus dropped: the window still looks active but no
# surface holds the keyboard, so you can't type until you switch workspaces
# (a workspace change re-runs Hyprland's focus logic). This automates that.
#
# Wired to run after every reload from two places:
#   - Hyprland   : `exec = …/refocus.sh` in custom/general.conf  (per reload)
#   - Quickshell : a Timer in shell.qml                          (per reload)
#
set -u

# Let the layer surfaces finish settling before grabbing focus back.
readonly SETTLE_DELAY=0.2

# Address of the window to focus: the active one, or — if Hyprland reports
# none — the first window on the current workspace.
target_window() {
    local addr ws
    addr="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')"
    if [[ -n "$addr" && "$addr" != "0x0" ]]; then
        printf '%s' "$addr"
        return
    fi
    ws="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')"
    hyprctl clients -j 2>/dev/null \
        | jq -r --argjson w "${ws:-1}" \
            'map(select(.workspace.id == $w))[0].address // empty'
}

main() {
    sleep "$SETTLE_DELAY"
    local addr
    addr="$(target_window)"
    # `focuswindow` re-runs Hyprland's focus logic and re-asserts the wlroots
    # keyboard focus, even if Hyprland already considers the window active.
    [[ -n "$addr" ]] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
    return 0
}

main "$@"
