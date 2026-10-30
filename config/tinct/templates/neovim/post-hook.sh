#!/usr/bin/env bash
# Rewrite the A0 line of the cocoa palette to match the current $term0
# from quickshell's material_colors.scss.
#
# The template ships A0 = "__TERM0__" and this hook substitutes it. The
# old form was `sed s|__TERM0__|$t0|` — which only matched the literal
# placeholder. Whatever value won the FIRST race after a wallpaper change
# (often a stale scss because the renderer and the scss-generator ran in
# parallel) got baked in, and subsequent runs found no placeholder left
# and silently kept it. So the bg froze on whatever the very first
# theme had been, while every other themed app (wezterm etc.)
# kept tracking. Fix: rewrite the A0 = "..." line unconditionally on
# every hook, regardless of what value is currently in it.
set -e
SCSS="$HOME/.local/state/quickshell/user/generated/material_colors.scss"
OUT="$HOME/.local/state/quickshell/user/generated/nvim_colors.lua"
[ -r "$SCSS" ] || exit 0
[ -w "$OUT" ]  || exit 0

# Pull a $termN hex from the scss.
getterm() { awk -F'[ ;]+' -v k="\$term$1:" '$1==k {print $2; exit}' "$SCSS"; }

# Overwrite a cocoa slot's hex in place, preserving its trailing comment.
setslot() {
    [ -n "$2" ] && sed -i -E "s|^(  $1 = )\"[^\"]*\"(,.*)\$|\1\"$2\"\2|" "$OUT"
}

# Wait briefly if scss is being rewritten in parallel — small races between
# the renderer's post-hook fan-out and quickshell's scss writer have been seen.
for _ in 1 2 3 4 5; do
    t0=$(getterm 0)
    [ -n "$t0" ] && break
    sleep 0.1
done

if [ -n "$t0" ]; then
    # Make nvim use the SAME palette as the terminal: map the cocoa fg/accent/
    # semantic slots to the terminal's 16 ANSI colours ($term0..15). The dark
    # surface slots (A1/A2/A3/A5) have no ANSI equivalent, so they keep the palette values.
    # Base16-style assignment: 0 bg · 1 red · 2 green · 3 yellow · 4 blue ·
    # 5 magenta · 6 cyan · 7 fg · 15 bright-fg.
    setslot A0  "$t0"            # editor background
    setslot A4  "$(getterm 7)"   # normal fg
    setslot A6  "$(getterm 15)"  # brightest fg
    setslot B0  "$(getterm 4)"   # primary accent  → blue
    setslot B1  "$(getterm 6)"   # secondary accent → cyan
    setslot B2  "$(getterm 2)"   # tertiary accent → green
    setslot C0  "$(getterm 1)"   # error           → red
    setslot C4  "$(getterm 3)"   # warn            → yellow
    setslot C5  "$(getterm 6)"   # info accent     → cyan
    setslot C6  "$(getterm 4)"   # info            → blue
    setslot C7  "$(getterm 2)"   # hint            → green
    setslot C11 "$(getterm 5)"   # info            → magenta
    setslot C13 "$(getterm 15)"  # bright
    setslot C14 "$(getterm 1)"   # error variant   → red
fi

# Live-reload running nvim instances. The Signal autocmd in
# core.lazyload.themes re-applies the colorscheme.
pkill -SIGUSR1 nvim 2>/dev/null || true
