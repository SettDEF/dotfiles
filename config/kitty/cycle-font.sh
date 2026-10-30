#!/usr/bin/env bash
# Cycle through fonts listed in ~/.config/kitty/fonts.conf, rewrite
# current-font.conf, and ask the running kitty to reload its config.
#
# Direction:
#   $1 = "next" (default) or "prev"

set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
LIST="$CONF_DIR/fonts.conf"
CURRENT="$CONF_DIR/current-font.conf"
DIR="${1:-next}"

# Read non-comment, non-blank font lines into an array.
mapfile -t FONTS < <(grep -vE '^\s*(#|$)' "$LIST")
[ "${#FONTS[@]}" -gt 0 ] || { echo "fonts.conf is empty"; exit 1; }

# Current font (everything after "font_family ").
cur=""
if [ -f "$CURRENT" ]; then
	cur="$(sed -n 's/^font_family[[:space:]]\+//p' "$CURRENT" | head -n1)"
fi

# Find its index; default to -1 (so "next" wraps to 0).
idx=-1
for i in "${!FONTS[@]}"; do
	if [ "${FONTS[$i]}" = "$cur" ]; then idx=$i; break; fi
done

n=${#FONTS[@]}
case "$DIR" in
	prev) idx=$(( (idx - 1 + n) % n )) ;;
	*)    idx=$(( (idx + 1) % n )) ;;
esac

next="${FONTS[$idx]}"
printf 'font_family %s\n' "$next" > "$CURRENT"

LOG="$CONF_DIR/cycle-font.log"
exec >>"$LOG" 2>&1
echo "--- $(date) ---"
echo "writing: $next"
echo "KITTY_LISTEN_ON=$KITTY_LISTEN_ON"

# Reload kitty.conf so future windows get the new font, then nudge the font
# subsystem in existing windows. Kitty 0.46 doesn't expose a direct
# "set font family" remote command, but bumping the font size by +1 and back
# forces a glyph-cache rebuild that picks up the new family.
kitten @ load-config && echo "load-config OK" || echo "load-config FAILED"
kitten @ set-font-size -- +1 && echo "+1 OK" || echo "+1 FAILED"
kitten @ set-font-size -- -1 && echo "-1 OK" || echo "-1 FAILED"

command -v notify-send >/dev/null && notify-send -t 1500 "kitty font" "$next" || true
