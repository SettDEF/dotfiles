#!/usr/bin/env bash
# Supervise BOTH clipboard-history recorders (text + image).
#
#   start-cliphist-watch.sh [qsConfig]
#
# WHY ONE SCRIPT FOR BOTH
# The autostart guard that works here is `pgrep -x wl-paste` — an exact match on
# the process NAME. A per-type guard would need `pgrep -f`, which also matches
# the `sh -c` launching the command, so the guard would see itself and neither
# watcher would ever start.
#
# WHY A SUPERVISOR
# `wl-paste --watch` exits if it loses the seat or the compositor restarts, and
# nothing brought it back: clipboard history then silently stops recording for
# the rest of the session. Copying still appears to work — the clipboard itself
# is fine — but nothing calls `cliphist store`, so history stops growing. It
# surfaces hours later as "my clipboard index never updates".
#
# WHY wayland-ready
# Hyprland hands its exec children an EMPTY WAYLAND_DISPLAY, so wl-paste fell
# back to wayland-0, failed instantly, and this loop respawned it forever —
# supervisor alive, zero watchers, history dead. See wayland-ready.sh.
set -u
# Name the process so the autostart guard (`pgrep -x start-cliphist-`) can see
# it: under `#!/usr/bin/env bash` it is just "bash", and every Hyprland reload
# started another copy. The watch loops below inherit the name.
printf %s start-cliphist- > /proc/$$/comm

CONFIG="${1:-ii}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$HERE/wayland-ready.sh"
if ! wayland_ready; then
    echo "start-cliphist-watch: no Wayland socket appeared; giving up" >&2
    exit 1
fi

watch_type() {
    local type="$1" fails=0
    while true; do
        wl-paste --type "$type" --watch bash -c \
            "cliphist store && qs -c '$CONFIG' ipc call cliphistService update"
        # Exited: compositor restart, seat loss, or a transient failure. Pause
        # so a hard failure cannot become a hot loop, then re-attach.
        fails=$(( fails + 1 ))
        if [ "$fails" -ge 10 ]; then
            # Something is persistently wrong (bad env, missing binary). Back
            # off hard rather than spinning invisibly forever, which is exactly
            # how this failed silently before.
            echo "start-cliphist-watch: '$type' watcher failed $fails times; backing off" >&2
            sleep 60
            fails=0
        else
            sleep 2
        fi
    done
}

watch_type text &
watch_type image &

# Keep the supervisor alive so both children stay parented to it.
wait
