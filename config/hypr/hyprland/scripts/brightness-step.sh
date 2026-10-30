#!/bin/sh
# Step the panel backlight without ever entering the firmware curve's dead zone.
# This eDP panel (ROG Flow Z13 2025 / GZ302EA, amdgpu_bl1) has a firmware
# brightness curve that FOLDS OVER at the top. amdgpu logs "Using custom
# brightness curve"; the scale is non-linear. Measured by writing raw values
# and reading actual_brightness back (max_brightness = 65535):
#
#       0 ..  3276  -> actual  3084   clamped lit floor
#   64224  (98%)    -> actual 65290   brightest, stable
#   64450           -> actual 65535   last good value
#   64550           -> actual     0   backlight OFF
#   65535 (100%)    -> actual     0   backlight OFF
#
# So 100% is genuinely darker than 0%: at 0 the panel stays lit at its floor,
# at 100 the backlight switches off. Cap at 98% -> 99.6% of maximum light.
#
# The quickshell service already caps itself, but the keybind falls back to
# brightnessctl when the shell is unresponsive, and brightnessctl will happily
# write 65535. So the clamp lives here, after whichever path ran.

DEV=amdgpu_bl1
SYS=/sys/class/backlight/$DEV

case "$1" in
    up)   qs -c ii ipc call brightness increment >/dev/null 2>&1 || brightnessctl -d "$DEV" -q s 5%+ ;;
    down) qs -c ii ipc call brightness decrement >/dev/null 2>&1 || brightnessctl -d "$DEV" -q s 5%- ;;
    *)    echo "usage: $0 up|down" >&2; exit 2 ;;
esac

# Clamp below the dead value, whichever path set it.
max=$(cat "$SYS/max_brightness" 2>/dev/null) || exit 0
cur=$(cat "$SYS/brightness" 2>/dev/null) || exit 0
cap=$(( max * 98 / 100 ))
[ "$cur" -gt "$cap" ] && brightnessctl -d "$DEV" -q s "$cap"

exit 0
