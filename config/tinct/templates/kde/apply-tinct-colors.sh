#!/usr/bin/env bash
# Applies the tinct-rendered KDE colour scheme (the theme's own colours, not Material You); kded's
# GTK bridge then rewrites ~/.config/gtk-{3,4}.0/colors.css from it.
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/Tinct.colors"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"
[[ -f "$STATE" ]] || { echo "no $STATE: tinct has not rendered it yet" >&2; exit 1; }

# KDE ignores a scheme that is already the current one, so alternate between two names
current=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)
name=TinctA
[[ "$current" == "TinctA" ]] && name=TinctB

mkdir -p "$DIR"
sed -e "s/^ColorScheme=.*/ColorScheme=$name/" -e "s/^Name=.*/Name=$name/" "$STATE" > "$DIR/$name.colors"
plasma-apply-colorscheme "$name" >/dev/null
