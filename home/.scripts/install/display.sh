#!/bin/bash

source "$(dirname $0)/../utils.sh"

# Display manager — superseded by install/greeter.sh which installs the
# Quickshell-on-greetd greeter. We skip the sddm enable/disable dance
# here so a fresh install doesn't briefly flash sddm before greeter.sh
# tears it down. SDDM theme files are still copied below so they're
# available if you ever want to fall back to sddm.

# Nordic
# sudo cp $USER_HOME/.wallpapers/National_Park_Nord.png /usr/share/sddm/themes/sugar-candy/Backgrounds/Mountain.jpg

# Tokyonight (only copied if the sddm sugar-candy theme is installed)
if [ -d /usr/share/sddm/themes/sugar-candy/Backgrounds ]; then
    sudo cp $USER_HOME/.wallpapers/Tokyonight_Street_2.png \
        /usr/share/sddm/themes/sugar-candy/Backgrounds/Mountain.jpg
fi

# Setup lock screen.
# Should this script run every time the screens change?  Yeah.

# Nordic
# betterlockscreen -u $USER_HOME/.wallpapers/National_Park_Nord.png --display 1
# betterlockscreen -u $USER_HOME/.wallpapers/National_Park_Nord.png --blur 0.5 --display 1

# Tokyonight
betterlockscreen -u $USER_HOME/.wallpapers/tokyo-night-space_upscaled.png --display 1 &
betterlockscreen -u $USER_HOME/.wallpapers/tokyo-night-space_upscaled.png --blur 0.5 --display 1 &
