#!/bin/bash
# Check if internet is working

if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "✓ Network is up"
    notify-send "Network Status" "Connected"
else
    echo "✗ Network is down"
    notify-send -u critical "Network Status" "No internet connection"
fi
