#!/usr/bin/env bash
# Watch KDE config directory and run sync-kde-theme.sh instantly on changes.
#
# Run this in the background at startup.

CONFIG_DIR="$HOME/.config"
SYNC_SCRIPT="$HOME/.config/hypr/hyprland/scripts/sync-kde-theme.sh"

# Ensure the files exist
touch "$CONFIG_DIR/kdeglobals" "$CONFIG_DIR/kcminputrc"

# Start monitoring config directory.
#
# Debounced: a theme/colour apply rewrites kdeglobals several times in a quick
# burst (kde-material-colors + changeAdwColors.py, plus the tinct pipeline
# running twice). The old code ran the sync once per write, so its
# "Theme applied" notification fired two (or more) times for a single change.
# Now each matching event cancels any pending run and re-arms a single deferred
# one, so a burst collapses into exactly one sync + one notification.
pending=""
inotifywait -m -e close_write,moved_to --format "%f" "$CONFIG_DIR/" 2>/dev/null | while read -r filename; do
    case "$filename" in
        kdeglobals|kcminputrc) ;;
        *) continue ;;
    esac
    [ -n "$pending" ] && kill "$pending" 2>/dev/null
    { sleep 1; "$SYNC_SCRIPT"; } &
    pending=$!
done
