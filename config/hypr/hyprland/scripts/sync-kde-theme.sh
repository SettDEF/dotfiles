#!/usr/bin/env bash
# Push KDE Settings choices (icons, cursor, GTK theme) out to the live
# session. Run after picking a theme in System Settings so already-open
# apps refresh without a restart.
#
# Zero background overhead — invoked manually or via a keybind.
set -u

gi() { grep -m1 "^${1}=" ~/.config/kcminputrc 2>/dev/null | cut -d= -f2-; }

# Read the icon theme from the [Icons] GROUP specifically. A bare
# `grep -m1 "^Theme="` matched the FIRST Theme= anywhere in kdeglobals —
# which is [Sounds]Theme=freedesktop whenever tinct/KDE writes [Sounds]
# above [Icons]. That silently set the icon theme to a non-existent one and
# flipped every icon to the hicolor/breeze fallback ("old icons"). Read the
# group explicitly so section order can't matter.
icon=$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)
[ -z "$icon" ] && icon=$(kreadconfig5 --file kdeglobals --group Icons --key Theme 2>/dev/null)
[ -z "$icon" ] && icon=$(awk -F= '/^\[Icons\]/{f=1;next} /^\[/{f=0} f&&/^Theme=/{print $2;exit}' ~/.config/kdeglobals)
cursor=$(gi cursorTheme)
csize=$(gi cursorSize)
sens=$(gi PointerAcceleration)
profile=$(gi PointerAccelerationProfile)
flat=$(gi X11LibInputXAccelProfileFlat)

[ -n "$icon" ]   && gsettings set org.gnome.desktop.interface icon-theme   "$icon"   2>/dev/null
[ -n "$cursor" ] && {
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null
    hyprctl setcursor "$cursor" "${csize:-24}" >/dev/null 2>&1
}

# Update GTK 3.0, GTK 4.0, and GTK 2.0 configuration files in real-time
for file in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
    if [ -f "$file" ]; then
        [ -n "$icon" ]   && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icon/" "$file"
        [ -n "$cursor" ] && sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$cursor/" "$file"
        [ -n "$csize" ]  && sed -i "s/^gtk-cursor-theme-size=.*/gtk-cursor-theme-size=$csize/" "$file"
    fi
done

if [ -f ~/.gtkrc-2.0 ]; then
    [ -n "$icon" ]   && sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name="'"$icon"'"/' ~/.gtkrc-2.0
    [ -n "$cursor" ] && sed -i 's/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name="'"$cursor"'"/' ~/.gtkrc-2.0
    [ -n "$csize" ]  && sed -i 's/^gtk-cursor-theme-size=.*/gtk-cursor-theme-size='"$csize"'/' ~/.gtkrc-2.0
fi

# Apply mouse sensitivity (PointerAcceleration) from kcminputrc to Hyprland
if [ -n "$sens" ]; then
    hyprctl keyword input:sensitivity "$sens" >/dev/null 2>&1
fi

# Apply mouse acceleration profile from kcminputrc to Hyprland
if [ "$profile" = "1" ] || [ "$flat" = "true" ]; then
    hyprctl keyword input:accel_profile "flat" >/dev/null 2>&1
elif [ "$profile" = "2" ] || [ "$flat" = "false" ]; then
    hyprctl keyword input:accel_profile "adaptive" >/dev/null 2>&1
fi

# Best-effort D-Bus broadcast so any KDE-aware app still listening
# refreshes its icon cache. No-op if dbus-send isn't installed.
command -v dbus-send >/dev/null && \
    dbus-send --session --type=signal /KGlobalSettings \
        org.kde.KGlobalSettings.notifyChange int32:4 int32:0 2>/dev/null

# Only notify when the icon/cursor theme actually changed. Colour-only updates
# (wallpaper / tinct) also rewrite kdeglobals and trigger this sync, but the
# icons/cursor are identical — firing "Theme applied" for those just spams the
# notification centre. The gsettings/gtk/hyprctl sync above still runs every
# time (idempotent); only the toast is gated.
sig="${icon}|${cursor}|${csize}"
sigfile="${XDG_CACHE_HOME:-$HOME/.cache}/sync-kde-theme.last"
if [ "$sig" != "$(cat "$sigfile" 2>/dev/null)" ]; then
    printf '%s' "$sig" > "$sigfile"
    notify-send -a "Theme sync" "Theme applied" "icons: $icon · cursor: $cursor"
fi
