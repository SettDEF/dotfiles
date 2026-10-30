#!/usr/bin/env bash
# Launch the quickshell config once the compositor can actually accept it.
#
#   start-quickshell.sh [config]      (default: ii)
#
# Hyprland runs exec-once entries while it is still coming up, and hands those
# children an EMPTY WAYLAND_DISPLAY. Qt then fails platform init outright:
#
#   Failed to create wl_display (Connection refused)
#   Could not load the Qt platform plugin "wayland" ...
#   -> QGuiApplicationPrivate::createEventDispatcher -> qFatal -> SIGABRT
#
# quickshell's own crash handler forks a bare `quickshell` to report the crash,
# which is headless and aborts the same way — so every failed attempt produces
# TWO coredumps. The previous config just retried 30 times, which is where the
# 60-coredump logins came from.
#
# So: resolve the socket properly, then start. A bounded retry stays as a safety
# net for the case where the socket exists but is not yet accepting.
set -u

CONFIG="${1:-ii}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$HERE/wayland-ready.sh"
if ! wayland_ready; then
    echo "start-quickshell: no Wayland socket appeared; giving up" >&2
    exit 1
fi

export QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}"

# Cap glibc malloc arenas.
#
# glibc gives each thread its own arena and allows 8 per core before reusing —
# on this 32-core machine that is up to 256. Quickshell runs ~120 threads, and
# arenas hold on to freed memory instead of returning it to the OS, so the
# shell sat on ~770MB of anonymous memory backed by 2.6GB of virtual data
# spread across 268 separate mappings.
#
# Two arenas is the usual recommendation for a GUI process: contention is
# irrelevant here (this is not an allocation-heavy server), and the freed
# memory actually comes back.
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
# Return freed chunks to the OS sooner rather than hoarding them in the heap.
export MALLOC_TRIM_THRESHOLD_="${MALLOC_TRIM_THRESHOLD_:-131072}"


# Normally the first attempt wins now that the environment is correct. The
# retries only cover a socket that exists but is still refusing connections;
# without them a single unlucky start would leave the session with no shell.
for attempt in $(seq 1 10); do
    # Silence the two categories that dominate the log. Between them the
    # scanner and the interceptor wrote ~540KB on EVERY reload - and the logs
    # live in /run, which is tmpfs, so that is RAM. Warnings and errors are
    # untouched; only their debug chatter is dropped.
    qs -n -c "$CONFIG" \
        --log-rules "quickshell.qmlscanner.debug=false;quickshell.interceptor.debug=false" \
        && exit 0
    echo "start-quickshell: attempt $attempt failed, retrying" >&2
    sleep 1
done

echo "start-quickshell: gave up after 10 attempts" >&2
exit 1
