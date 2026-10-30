#!/usr/bin/env bash
# Watches the nuke enclosure's PCIe chain. Discovers devices dynamically, because
# the PCI addresses change depending on whether it is behind the dock or direct.
# Reads PCI config space only - never /dev/nvme* or the mount. Stop by PID.
set -u
LOG="${1:-$HOME/.cache/nuke-linkwatch.log}"
last=""; beat=0

chain() {   # the Samsung, then every PCI parent up to the root
    local nv p out=""
    nv=$(lspci -d 144d:a810 2>/dev/null | cut -d' ' -f1 | head -1)
    [ -n "$nv" ] || { echo "ENCLOSURE-ABSENT"; return; }
    p=$(readlink -f "/sys/bus/pci/devices/0000:$nv" 2>/dev/null)
    while [ -n "$p" ] && [ "${p##*/}" != "pci0000:00" ]; do
        b=${p##*/}; [ "${b:0:5}" = "0000:" ] || break
        out+="${b#0000:}=$(cat $p/current_link_speed 2>/dev/null | cut -d' ' -f1)x$(cat $p/current_link_width 2>/dev/null) "
        p=$(dirname "$p")
    done
    echo "$out"
}

while :; do
    now=$(chain)
    if [ "$now" != "$last" ]; then
        printf '%s CHANGE %s\n' "$(date '+%F %T')" "$now" >> "$LOG"
        last="$now"; beat=0
    elif [ $beat -ge 60 ]; then
        printf '%s ok     %s\n' "$(date '+%F %T')" "$now" >> "$LOG"; beat=0
    fi
    beat=$((beat + 1)); sleep 1
done
