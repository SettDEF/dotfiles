#!/bin/bash
# Deploy the Quickshell greetd greeter — re-runnable after every fresh
# install. Source of truth lives in the dotfiles git repo under
# ~/dotfiles/greetd/ (persistent across reinstall via git clone); this
# script copies it into /etc/greetd/ and enables greetd as the system
# display manager.
#
# Idempotent: safe to re-run; existing config.toml is backed up before
# overwrite, files are install -m'd so perms are always reset.

source "$(dirname "$0")/../utils.sh"

SRC="$USER_HOME/.etc/greetd"
DEST="/etc/greetd"

if [ ! -d "$SRC" ]; then
    echo "  ✘ $SRC missing — nothing to install."
    exit 1
fi

# 1. Ensure required packages
sudo pacman -S --needed --noconfirm greetd hyprland quickshell python jq

# 2. Backup existing greetd config
if [ -f "$DEST/config.toml" ]; then
    sudo cp -a "$DEST/config.toml" "$DEST/config.toml.backup-$(date +%Y%m%d-%H%M%S)"
fi

# 3. Deploy files
sudo mkdir -p "$DEST/quickshell-greeter"
sudo install -m 0644 "$SRC/config.toml"                          "$DEST/config.toml"
sudo install -m 0644 "$SRC/hyprland.conf"                        "$DEST/hyprland.conf"
# DMS-style launcher: sets HOME/XDG, generates a temp Hyprland config,
# execs Hyprland under dbus-run-session. Must be executable + readable
# by everyone (the `greeter` user runs it directly from greetd).
sudo install -m 0755 "$SRC/launcher.sh"                          "$DEST/launcher.sh"
# PAM service file → /etc/pam.d/greetd-greeter. Adds pam_gnome_keyring
# so the login.keyring auto-unlocks on auth — no separate prompt.
sudo install -m 0644 "$SRC/pam.d-greetd-greeter"                 "/etc/pam.d/greetd-greeter"
sudo install -m 0644 "$SRC/quickshell-greeter/shell.qml"         "$DEST/quickshell-greeter/shell.qml"
sudo install -m 0644 "$SRC/quickshell-greeter/Greeter.qml"       "$DEST/quickshell-greeter/Greeter.qml"
[ -f "$SRC/quickshell-greeter/CookieClock.qml" ] && \
    sudo install -m 0644 "$SRC/quickshell-greeter/CookieClock.qml"   "$DEST/quickshell-greeter/CookieClock.qml"
sudo install -m 0755 "$SRC/quickshell-greeter/greetd-bridge.py"  "$DEST/quickshell-greeter/greetd-bridge.py"

# Cache dir the launcher will redirect HOME to. Owned by greeter so
# it can actually write there.
sudo mkdir -p /var/cache/quickshell-greeter
sudo chown greeter:greeter /var/cache/quickshell-greeter
sudo chmod 0700 /var/cache/quickshell-greeter

# 4. Material theme: seed with the user's current tinct colors so
# the greeter visually matches the session even before the user logs in
# and regenerates anything.
GENCOL="$USER_HOME/.local/state/quickshell/user/generated/colors.json"
if [ -f "$GENCOL" ]; then
    sudo install -m 0644 "$GENCOL" "$DEST/quickshell-greeter/colors.json"
else
    echo "  ⚠ no colors.json under $GENCOL — greeter will use fallback palette."
fi

# 5. Wallpaper: copy the current wallpaper source (un-walltuned) so
# the greeter looks like the desktop the user is about to enter.
CFG="$USER_HOME/.config/illogical-impulse/config.json"
if [ -f "$CFG" ]; then
    WP=$(jq -r '.background.wallpaperSourcePath // .background.wallpaperPath // empty' "$CFG" 2>/dev/null)
    if [ -n "$WP" ] && [ -f "$WP" ]; then
        case "${WP,,}" in
            *.jpg|*.jpeg) sudo install -m 0644 "$WP" "$DEST/quickshell-greeter/wallpaper.jpg" ;;
            *.png)        sudo install -m 0644 "$WP" "$DEST/quickshell-greeter/wallpaper.png" ;;
            *)            echo "  ⚠ skipping non-image wallpaper $WP" ;;
        esac
    fi
fi

# 6. Permissions: greeter user needs read access to everything under
# /etc/greetd/quickshell-greeter/. Group-read only — we never want
# world-readable wallpaper / colors on a multi-user box.
sudo chown -R root:greeter "$DEST/quickshell-greeter"
sudo chmod -R o-rwx,g+rX,u+rwX "$DEST/quickshell-greeter"

# 6b. Live-update cache. The user (your login user) needs write here to
# sync new colors / wallpapers from the session; the `greeter` user
# needs read so the next login screen picks them up. Use the user's
# primary group as owner; `greeter` is the group.
CALLER="${SUDO_USER:-$USER}"
CALLER_GROUP=$(id -gn "$CALLER")
sudo mkdir -p /var/cache/greeter
sudo chown "$CALLER:greeter" /var/cache/greeter
sudo chmod 0750 /var/cache/greeter
# Seed it with the current live colors + wallpaper so the very first
# greeter render after install matches what's on the session, even if
# you reboot without doing another wallpaper / theme change.
[ -f "$DEST/quickshell-greeter/colors.json" ] && \
    sudo install -m 0640 -o "$CALLER" -g greeter \
        "$DEST/quickshell-greeter/colors.json" /var/cache/greeter/colors.json
for ext in jpg png; do
    [ -f "$DEST/quickshell-greeter/wallpaper.$ext" ] && \
        sudo install -m 0640 -o "$CALLER" -g greeter \
            "$DEST/quickshell-greeter/wallpaper.$ext" /var/cache/greeter/wallpaper.$ext
done

# 6c. Auto-sync hooks. We append a trailer block to applycolor.sh and
# switchwall.sh that copies the freshly-written artifact into
# /var/cache/greeter/ — so every walltune apply + every wallpaper
# change keeps the greeter in lockstep with the session.
APPLY="$USER_HOME/.config/quickshell/ii/scripts/colors/applycolor.sh"
SWITCH="$USER_HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
TAG="# GREETER-SYNC"  # idempotency marker
if [ -f "$APPLY" ] && ! grep -q "$TAG" "$APPLY"; then
    cat >> "$APPLY" <<EOF

$TAG : keep /var/cache/greeter/colors.json in sync with the session
if [ -w /var/cache/greeter ]; then
    cp "\$colors_json_path" /var/cache/greeter/colors.json 2>/dev/null
fi
EOF
fi
if [ -f "$SWITCH" ] && ! grep -q "$TAG" "$SWITCH"; then
    cat >> "$SWITCH" <<EOF

$TAG : keep /var/cache/greeter/wallpaper.* in sync with the session
if [ -w /var/cache/greeter ]; then
    # The current wallpaperPath might be a walltune-processed PNG; we
    # prefer the wallpaperSourcePath (the un-edited original) so the
    # greeter shows the same source the user picked, not a tinted copy.
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
fi

# 7. DM swap — disable whatever is currently active, enable greetd.
# `display-manager.service` is the systemd alias every DM installs;
# disabling it is enough to flip ownership to whatever we enable next.
if systemctl is-enabled --quiet display-manager 2>/dev/null; then
    CURRENT_DM=$(systemctl status display-manager 2>/dev/null | head -1 | awk '{print $2}')
    if [ "$CURRENT_DM" != "greetd.service" ]; then
        echo "  ↻ Disabling $CURRENT_DM"
        sudo systemctl disable --now display-manager 2>/dev/null || true
    fi
fi
sudo systemctl enable greetd

echo
echo "  ✔ Quickshell greeter installed at $DEST."
echo "  → On next boot greetd will take VT 1."
echo "  → To roll back: sudo systemctl disable greetd && sudo systemctl enable <old-dm>"
