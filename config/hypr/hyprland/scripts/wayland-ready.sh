# Shared helper: block until the Wayland socket exists, and make sure
# WAYLAND_DISPLAY actually names it. Source this, do not execute it.
#
# WHY THIS IS NEEDED
# Hyprland's exec-once children inherit WAYLAND_DISPLAY as an EMPTY string —
# set, but with no value — because the compositor has not exported it yet when
# the autostarts fire. That breaks two ways:
#
#   * Clients that read it fall back to `wayland-0`, which does not exist here
#     (Hyprland is on wayland-1), and exit immediately:
#         Failed to connect to a Wayland server: No such file or directory
#         Note: WAYLAND_DISPLAY is unset (falling back to wayland-0)
#   * Qt apps abort outright in QGuiApplicationPrivate::createEventDispatcher().
#
# An empty value also defeats `${WAYLAND_DISPLAY:-wayland-1}`-style guessing in
# the caller, because guessing the NAME does not help a child that reads the
# empty variable itself. So resolve the real socket and export it.
#
# Sets WAYLAND_DISPLAY and returns 0 on success, 1 on timeout (~10s).
wayland_ready() {
    local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local i s

    for i in $(seq 1 100); do
        # Already usable? Accept it and stop.
        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ]; then
            export WAYLAND_DISPLAY
            return 0
        fi
        # Otherwise adopt whichever wayland-N socket the compositor created.
        for s in "$runtime"/wayland-*; do
            case "$s" in
                *.lock) continue ;;
            esac
            if [ -S "$s" ]; then
                WAYLAND_DISPLAY="${s##*/}"
                export WAYLAND_DISPLAY
                return 0
            fi
        done
        sleep 0.1
    done
    return 1
}
