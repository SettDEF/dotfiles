#!/usr/bin/env bash
DECORATION_SO="/var/cache/hyprpm/caesar/hyprland-plugins/hyprbars.so"

if hyprctl plugin list | grep -q "hyprbars"; then
    hyprctl plugin unload "$DECORATION_SO"
    hyprctl notify 1 2000 "rgb(ff5f56)" "Window Decorations: OFF"
else
    hyprctl plugin load "$DECORATION_SO"
    hyprctl notify 2 2000 "rgb(27c93f)" "Window Decorations: ON"
fi
