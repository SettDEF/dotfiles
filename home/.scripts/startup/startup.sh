#!/bin/bash
# Core components (order is important!)
    # nvidia-force-comp-pipeline
    # ~/.scripts/screenlayout/default_double_monitor.sh
    #~/.scripts/screenlayout/default_double_monitor_ag.sh
    # feh --randomize --bg-fill ~/.wallpapers/**
    # xborders -c ~/.config/picom/xborder.json
    # nice -n -20 ~/.config/polybar/launch.sh
    # nice -n 19 betterlockscreen -u "${HOME}/.wallpapers/tokyo-night-space_upscaled.png" --display 1 &
xrandr --output eDP-1 --auto

~/.scripts/rdmcpape ~/.wallpapers
picom -b
# Services
# ~/.config/cron/update_loadshedding.sh &
# ~/.config/tmux/utils/start_all_servers.sh &
# dbus-launch dunst --config ~/.config/dunst/dunstrc &
# /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
# birdtray &
# xsettingsd &

# Apps
# xdg-settings set default-web-browser librewolf.desktop
# Keyboard stuff
# setxkbmap -option caps:escape
xset r rate 165 50
xmodmap ~/.Xmodmap
xbindkeys

# Mounts
# if [[ -d "/mnt/usr/mars/Documents" ]]; then
#     mountpoint -q "$HOME/Documents" || sudo mount --bind /mnt/usr/mars/Documents "$HOME/Documents"
#     echo -e "\e[90;2;5m /mnt/usr/mars/Documents mounted"
# fi
HOUR=$(date '+%H')
if [[ $HOUR -ge 22 || $HOUR -le 6 ]]; then
    redshift -o -t 3500:3500   # Apply fixed warm temperature (adjust 3500K as desired)
    # Or just: redshift -O 3500  # Instant set, no transition/daemon
fi

