#!/usr/bin/env bash
#
# clip2path.sh — bridge a clipboard IMAGE into terminal apps that can't read
# clipboard images.
#
# Claude Code on Linux/Wayland cannot paste an image directly from the
# clipboard (upstream limitation — Ctrl+V image paste is macOS-only). It can,
# however, read an image given a file PATH. So: if the clipboard holds an
# image, save it to a temp PNG and type that path into the focused window.
#
# Bound to Super+Shift+V. Workflow: take a screenshot as usual (the image
# lands on the clipboard), focus the terminal, press Super+Shift+V — the
# path is typed in; review it and hit Enter.
#
set -u

dir="${XDG_RUNTIME_DIR:-/tmp}/clip-images"
mkdir -p "$dir"
# Drop temp images older than a day so the directory doesn't grow forever.
find "$dir" -maxdepth 1 -type f -mtime +1 -delete 2>/dev/null

if ! wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
    notify-send -a "Paste image" "No image on the clipboard" \
        "Copy a screenshot first, then press Super+Shift+V." 2>/dev/null
    exit 0
fi

f="$dir/clip-$(date '+%Y%m%d-%H%M%S').png"
if wl-paste --type image/png > "$f" 2>/dev/null && [ -s "$f" ]; then
    # Wait for Super+Shift to be physically released — otherwise wtype's
    # synthesized keystrokes combine with the held modifiers and mangle
    # the path.
    sleep 0.25
    # Trailing space so the user can keep typing after the path.
    wtype "$f "
    notify-send -a "Paste image" -i "$f" "Image path inserted" "$f" 2>/dev/null
else
    rm -f "$f"
    notify-send -a "Paste image" -u critical \
        "Could not read the clipboard image" 2>/dev/null
fi
