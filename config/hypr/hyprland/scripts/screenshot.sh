#!/usr/bin/env bash
# Screenshot helper for skwd-style Print-key bindings.
#
# Why this exists: under uwsm/greetd, Hyprland's frozen-at-exec
# environment can hold a stale HYPRLAND_INSTANCE_SIGNATURE that points
# to a socket that no longer exists. The inline keybind
#
#   bindl = ,Print,exec, grim -o "$(hyprctl activeworkspace -j | jq -r .monitor)" - | wl-copy
#
# silently fails because hyprctl can't connect → jq sees empty input
# → grim gets -o "" → it writes nothing → wl-copy gets nothing → empty
# clipboard. This wrapper rediscovers the live signature from the
# filesystem (same as workspace_action.sh) and then takes the shot.
#
# Usage:
#   screenshot.sh clip          # active monitor → clipboard only
#   screenshot.sh file          # active monitor → clipboard + save to ~/Pictures/Screenshots/
#   screenshot.sh region clip   # slurp region → clipboard
#   screenshot.sh region file   # slurp region → clipboard + save
#   screenshot.sh full clip     # all outputs joined → clipboard
#
# Set CURSOR=1 to include the mouse cursor (grim -c). This captures the
# cursor the compositor is actually drawing, so app-specific and custom
# cursors come out correct. Not applied to region mode, where the cursor
# would just be slurp's crosshair.
set -u

cursor_arg=()
[ "${CURSOR:-0}" = "1" ] && cursor_arg=(-c)

# Rediscover live HYPRLAND_INSTANCE_SIGNATURE.
_rt="${XDG_RUNTIME_DIR:-/run/user/$(/usr/bin/id -u)}"
# only when our own instance's socket is gone (a stale login env): never another compositor's (loom)
if [ ! -S "$_rt/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/.socket.sock" ]; then
_sig=$(/usr/bin/ls -t "$_rt/hypr" 2>/dev/null \
    | /usr/bin/grep -E '^[a-f0-9]+_[0-9]+_[0-9]+$' \
    | while read -r s; do
        [ -S "$_rt/hypr/$s/.socket.sock" ] && { echo "$s"; break; }
      done)
[ -n "$_sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
fi

# Which monitor to capture?  For most modes we use the active monitor.
active_monitor() {
    /usr/bin/hyprctl activeworkspace -j 2>/dev/null \
        | /usr/bin/jq -r '.monitor // empty'
}

screenshot_dir="$(/usr/bin/xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$screenshot_dir"
ts="$(/usr/bin/date '+%Y-%m-%d_%H.%M.%S')"
out_file="$screenshot_dir/Screenshot_${ts}.png"

mode="${1:-clip}"
sink="${2:-clip}"  # ignored for non-region modes (mode itself selects clip/file)

case "$mode" in
    clip)
        # active monitor → clipboard only
        mon="$(active_monitor)"
        [ -z "$mon" ] && { echo "no active monitor" >&2; exit 1; }
        /usr/bin/grim "${cursor_arg[@]}" -o "$mon" - | /usr/bin/wl-copy
        ;;
    file)
        # active monitor → clipboard AND file
        mon="$(active_monitor)"
        [ -z "$mon" ] && { echo "no active monitor" >&2; exit 1; }
        # Write file first, then pipe same bytes to wl-copy so we don't
        # screenshot twice.
        /usr/bin/grim "${cursor_arg[@]}" -o "$mon" "$out_file"
        /usr/bin/wl-copy < "$out_file"
        /usr/bin/notify-send -a "Screenshot" "Saved" "$out_file" -i "$out_file"
        ;;
    region)
        # slurp region → clipboard (+ file if "$sink" == file)
        geom=$(/usr/bin/slurp 2>/dev/null) || exit 0  # user cancelled
        if [ "$sink" = "file" ]; then
            /usr/bin/grim -g "$geom" "$out_file"
            /usr/bin/wl-copy < "$out_file"
            /usr/bin/notify-send -a "Screenshot" "Saved" "$out_file" -i "$out_file"
        else
            /usr/bin/grim -g "$geom" - | /usr/bin/wl-copy
        fi
        ;;
    full)
        # All outputs joined → clipboard (+ file if "$sink" == file)
        if [ "$sink" = "file" ]; then
            /usr/bin/grim "${cursor_arg[@]}" "$out_file"
            /usr/bin/wl-copy < "$out_file"
            /usr/bin/notify-send -a "Screenshot" "Saved" "$out_file" -i "$out_file"
        else
            /usr/bin/grim "${cursor_arg[@]}" - | /usr/bin/wl-copy
        fi
        ;;
    *)
        echo "Usage: $0 {clip|file|region [clip|file]|full [clip|file]}" >&2
        exit 2
        ;;
esac
