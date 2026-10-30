#!/bin/bash
# mount_nuke-9100.sh — EPIC NVMe/SCSI AUTO-MOUNT DAEMON
# ASUS ROG Flow Z13 + UGREEN 40Gbps + Samsung 9100 PRO 4TB
# Author: Caesar, Arch Linux 6.11+ | 2025

set -euo pipefail

TARGET="/mnt/NUKE-9100"
USER="caesar"
PART_SIZE=4000787030016
LABEL="NUKE-9100"
VENDOR_ID="2109"
PRODUCT_ID="8888"

# --- Find the correct partition ---
find_partition() {
    local dev
    # Prefer NVMe
    for dev in /dev/nvme*n1p2; do
        [[ -b "$dev" ]] || continue
        local size=$(blockdev --getsize64 "$dev")
        (( size == PART_SIZE )) && echo "$dev" && return 0
    done

    # Fallback: SCSI (sda2, sdb2, etc.)
    for dev in /dev/sd[a-z]2; do
        [[ -b "$dev" ]] || continue
        local size=$(blockdev --getsize64 "$dev")
        (( size == PART_SIZE )) && echo "$dev" && return 0
    done

    return 1
}

PART=$(find_partition) || { echo "NUKE-9100 not found."; exit 1; }
MODE=$( [[ "$PART" =~ ^/dev/nvme ]] && echo "NVMe" || echo "SCSI" )
SPEED=$( (( MODE == "NVMe" )) && echo "3.2 GB/s" || echo "~500 MB/s" )

# --- Force NVMe if possible (id override) ---
if [[ "$MODE" == "SCSI" ]]; then
    if ! lsmod | grep -q uas; then
        modprobe uas 2>/dev/null || true
    fi
    echo "$VENDOR_ID $PRODUCT_ID" > /sys/bus/usb/drivers/usb-storage/new_id 2>/dev/null || true
    # Give kernel 0.1s to rebind (no sleep, just hint)
    udevadm settle --timeout=2
    # Re-check
    NEW_PART=$(find_partition) || true
    [[ -n "$NEW_PART" && "$NEW_PART" =~ ^/dev/nvme ]] && PART="$NEW_PART" && MODE="NVMe" && SPEED="3.2 GB/s"
fi

# --- Ensure mountpoint ---
[[ -d "$TARGET" ]] || mkdir -p "$TARGET"

# --- Set label if wrong/missing ---
CURRENT_LABEL=$(lsblk -no LABEL "$PART" 2>/dev/null || echo "")
if [[ "$CURRENT_LABEL" != "$LABEL" ]]; then
    if command -v mlabel >/dev/null; then
        mlabel -i "$PART" "::${LABEL}"
    elif command -v fatlabel >/dev/null; then
        fatlabel "$PART" "$LABEL"
    fi
fi

# --- Mount ---
mount "$PART" "$TARGET"
chown "$USER:$USER" "$TARGET"

# --- EPIC ACTIVATION BOX ---
cat << EOF


    ╔══════════════════════════════════════════════════╗
    ║               N U K E - 9 1 0 0                  ║
    ║                                                  ║
    ║  ► DISK:  $PART                                  ║
    ║  ► MODE:  $MODE  ($SPEED)                 ║
    ║  ► MOUNT: $TARGET                               ║
    ║  ► OWNER: $USER                                   ║
    ║                                                  ║
    ║     ⚡ THUNDERBOLT NVME LOCKED & LOADED ⚡        ║
    ╚══════════════════════════════════════════════════╝


EOF

exit 0
