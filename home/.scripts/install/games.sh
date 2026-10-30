#!/bin/bash
# games.sh — game launcher integration.
#
# Lutris only makes per-game shortcuts on demand. This generates a .desktop
# launcher for every installed Lutris game and installs a systemd --user
# watcher on the Lutris library, so new games get an entry automatically.
#
# Implemented by ~/.scripts/lutris-desktop-sync (reads Lutris's SQLite DB
# directly, so it needs no display).

source "$(dirname $0)/../utils.sh"

if command -v lutris >/dev/null 2>&1; then
    "$USER_HOME/.scripts/lutris-desktop-sync" --install
else
    echo "lutris not installed — skipping game launcher sync"
fi
