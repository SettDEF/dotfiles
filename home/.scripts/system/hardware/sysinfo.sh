#!/bin/bash
# Display quick system info

echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "CPU: $(lscpu | grep "Model name" | cut -d ':' -f2 | xargs)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
echo "Battery: $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")%"
