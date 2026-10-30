#!/usr/bin/env bash

# 1. Check VPN Interface Status
# Look for common wireguard or openvpn interfaces (proton, windscribe, airvpn, wg, tun)
VPN_INTERFACE=$(ip link show | grep -E "wg0|proton|windscribe|airvpn|tun0|wg-|tun-" | grep -oP '^[0-9]+: \K[^:]+' | head -n 1)

if [ -n "$VPN_INTERFACE" ]; then
    # Return a green shield icon and the interface name
    VPN_STATUS="#[fg=green]󰒘 $VPN_INTERFACE"
else
    # Return a red warning icon
    VPN_STATUS="#[fg=red]󰒙 NO VPN"
fi

# 2. Check Tor Service Status
if systemctl is-active --quiet tor; then
    # Return a green onion icon
    TOR_STATUS="#[fg=green]󰒍 TOR"
else
    # Return a red warning onion icon
    TOR_STATUS="#[fg=red]󰒍 NO TOR"
fi

echo "$VPN_STATUS #[fg=white]| $TOR_STATUS "
