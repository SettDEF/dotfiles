#!/bin/bash
# Notify when battery is low or full

battery_level=$(cat /sys/class/power_supply/BAT0/capacity)
battery_status=$(cat /sys/class/power_supply/BAT0/status)

if [[ "$battery_level" -le 20 && "$battery_status" == "Discharging" ]]; then
    notify-send -u critical "Battery Low" "Battery at ${battery_level}%"
elif [[ "$battery_level" -ge 95 && "$battery_status" == "Charging" ]]; then
    notify-send "Battery Full" "Battery at ${battery_level}% - Consider unplugging"
fi
