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


# A GPU whose OpenGL driver has no window format with alpha (Intel Haswell and
# older, Mesa crocus) draws every see-through part of the shell black: the
# popups' shadow margins, rounded corners. Mesa's software OpenGL (llvmpipe) has
# them and still runs the shell's shaders; it costs CPU only while something
# animates (a start menu open: ~40 % of one core on an i3-4000M, idle: 0). Apps
# started from the shell go through Hyprland's exec, so they keep the GPU.
# But every texture then lives in RAM: the shell grew from ~540 MB to 1.3 GB and
# more, and a 4 GB laptop swapped until it froze. So only with 8 GB or more.
# Without the RAM, the shell stays on the GPU and is told (QS_NO_ALPHA): its
# popups then have no see-through margin, square corners and no slide.
mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
if [ -z "${LIBGL_ALWAYS_SOFTWARE:-}" ] && command -v python3 >/dev/null 2>&1 \
    && ! python3 -I "$HERE/egl-has-alpha.py" 2>/dev/null; then
    if [ "${mem_kb:-0}" -ge 7500000 ] && LIBGL_ALWAYS_SOFTWARE=1 python3 -I "$HERE/egl-has-alpha.py" 2>/dev/null; then
        echo "start-quickshell: this GPU cannot draw transparent windows; using llvmpipe" >&2
        export LIBGL_ALWAYS_SOFTWARE=1
    else
        echo "start-quickshell: this GPU cannot draw transparent windows; popups without see-through parts" >&2
        export QS_NO_ALPHA=1
    fi
fi

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
