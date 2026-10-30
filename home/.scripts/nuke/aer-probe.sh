#!/usr/bin/env bash
# Reads the AER + link-status registers straight out of PCI config space.
# The firmware owns AER on this root complex (_OSC denies it), so the kernel
# never reports these - but the hardware still latches them. Root required.
# Logs only on change, so a drop stands out. Stop by PID.
set -u
LOG="${1:-/var/log/nuke-aer.log}"
DEVS="0000:00:01.2 0000:61:00.0 0000:62:03.0 0000:a2:00.0 0000:a3:00.0 0000:a4:00.0"
last=""

snap() {
    for d in $DEVS; do
        [ -e "/sys/bus/pci/devices/$d" ] || { printf '%s=GONE ' "${d#0000:}"; continue; }
        # UESta/CESta = latched uncorrectable/correctable errors, LnkSta = live link state
        out=$(lspci -vv -s "$d" 2>/dev/null)
        ue=$(printf '%s' "$out" | grep -oP 'UESta:\s*\K.*' | tr -s ' ' | grep -oP '\w+\+' | tr '\n' ',' )
        ce=$(printf '%s' "$out" | grep -oP 'CESta:\s*\K.*' | tr -s ' ' | grep -oP '\w+\+' | tr '\n' ',' )
        ds=$(printf '%s' "$out" | grep -oP 'DevSta:\s*\K.*' | grep -oP '\w+Err\+' | tr '\n' ',' )
        ln=$(printf '%s' "$out" | grep -oP 'LnkSta:\s*Speed \K[0-9.]+GT/s.*?Width x[0-9]+' | tr -d ' ')
        printf '%s[%s|ue:%s|ce:%s|dev:%s] ' "${d#0000:}" "${ln:-?}" "${ue:--}" "${ce:--}" "${ds:--}"
    done
}

while :; do
    now=$(snap)
    if [ "$now" != "$last" ]; then
        printf '%s %s\n' "$(date '+%F %T')" "$now" >> "$LOG"
        last="$now"
    fi
    sleep 1
done
