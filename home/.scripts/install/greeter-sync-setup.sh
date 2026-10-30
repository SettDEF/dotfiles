#!/bin/bash
# Light-weight subset of install/greeter.sh — just the live-sync wiring:
#   * Creates /var/cache/greeter/ owned by caesar:greeter mode 0750
#   * Seeds it with the user's current colors + wallpaper
#   * Patches applycolor.sh + switchwall.sh with the GREETER-SYNC trailer
#     so future theme/wallpaper changes mirror automatically
#
# Use this when you want auto-sync to start working RIGHT NOW without
# also swapping display managers. The full install/greeter.sh does this
# step plus the DM swap.
#
# Re-runnable; the trailers are idempotency-tagged.

source "$(dirname "$0")/../utils.sh"

CACHE="/var/cache/greeter"
APPLY="$USER_HOME/.config/quickshell/ii/scripts/colors/applycolor.sh"
SWITCH="$USER_HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
TAG="# GREETER-SYNC"

# Whose files do we sync? When the script runs via sudo (without -E),
# $USER is "root" — so we fall back to $SUDO_USER, and only finally to
# $USER. Without this guard, the cache ends up owned by root:greeter
# and caesar can't write into it on theme changes.
TARGET_USER="${SUDO_USER:-$USER}"

# 1. Cache dir
sudo mkdir -p "$CACHE"
sudo chown "$TARGET_USER:greeter" "$CACHE"
sudo chmod 0750 "$CACHE"

# 2. Seed colors + wallpaper from current state
GENCOL="$USER_HOME/.local/state/quickshell/user/generated/colors.json"
if [ -f "$GENCOL" ]; then
    sudo install -m 0640 -o "$TARGET_USER" -g greeter "$GENCOL" "$CACHE/colors.json"
fi
CFG="$USER_HOME/.config/illogical-impulse/config.json"
if [ -f "$CFG" ] && command -v jq >/dev/null; then
    WP=$(jq -r '.background.wallpaperSourcePath // .background.wallpaperPath // empty' "$CFG" 2>/dev/null)
    if [ -n "$WP" ] && [ -f "$WP" ]; then
        case "${WP,,}" in
            *.jpg|*.jpeg) sudo install -m 0640 -o "$TARGET_USER" -g greeter "$WP" "$CACHE/wallpaper.jpg" ;;
            *.png)        sudo install -m 0640 -o "$TARGET_USER" -g greeter "$WP" "$CACHE/wallpaper.png" ;;
        esac
    fi
fi

# 3. applycolor.sh trailer
if [ -f "$APPLY" ] && ! grep -q "$TAG" "$APPLY"; then
    cat >> "$APPLY" <<EOF

$TAG : keep /var/cache/greeter/colors.json in sync with the session
if [ -w /var/cache/greeter ]; then
    cp "\$colors_json_path" /var/cache/greeter/colors.json 2>/dev/null
fi
EOF
    echo "  ✔ applycolor.sh patched"
fi

# 4. switchwall.sh trailer
if [ -f "$SWITCH" ] && ! grep -q "$TAG" "$SWITCH"; then
    cat >> "$SWITCH" <<EOF

$TAG : keep /var/cache/greeter/wallpaper.* in sync with the session
if [ -w /var/cache/greeter ]; then
    _gs_cfg="\$XDG_CONFIG_HOME/illogical-impulse/config.json"
    [ -z "\$XDG_CONFIG_HOME" ] && _gs_cfg="\$HOME/.config/illogical-impulse/config.json"
    if [ -f "\$_gs_cfg" ] && command -v jq >/dev/null; then
        _gs_wp=\$(jq -r '.background.wallpaperSourcePath // .background.wallpaperPath // empty' "\$_gs_cfg" 2>/dev/null)
        if [ -n "\$_gs_wp" ] && [ -f "\$_gs_wp" ]; then
            rm -f /var/cache/greeter/wallpaper.jpg /var/cache/greeter/wallpaper.png 2>/dev/null
            case "\${_gs_wp,,}" in
                *.jpg|*.jpeg) cp "\$_gs_wp" /var/cache/greeter/wallpaper.jpg 2>/dev/null ;;
                *.png)        cp "\$_gs_wp" /var/cache/greeter/wallpaper.png 2>/dev/null ;;
            esac
        fi
    fi
fi
EOF
    echo "  ✔ switchwall.sh patched"
fi

echo
echo "  Live cache state:"
ls -l "$CACHE" 2>/dev/null
echo
echo "  Theme will sync on the next walltune-apply / wallpaper change."
echo "  To force a sync right now: ~/.config/quickshell/ii/scripts/colors/applycolor.sh"
