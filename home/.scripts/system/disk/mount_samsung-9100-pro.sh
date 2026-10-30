# 1. Ordner anlegen
sudo mkdir -p /mnt/NUKE-9100

# 2. Skript updaten
cat > /home/caesar/.scripts/system/disk/mount_nuke-9100.sh << 'EOF'
#!/bin/bash

# =============================================
# NUKE-9100 AUTO-MOUNT → /mnt/NUKE-9100
# 4TB @ 3.2 GB/s | Arch Linux + USB4
# =============================================

sleep 10

# USB-Storage aktivieren
echo "2109 8888" > /sys/bus/usb/drivers/usb-storage/new_id 2>/dev/null || true

# NVMe + Thunderbolt
modprobe nvme 2>/dev/null || true
modprobe thunderbolt 2>/dev/null || true

sleep 8

MOUNTPOINT="/mnt/NUKE-9100"
PARTITION=""

if [ -b /dev/nvme0n1p2 ]; then
    PARTITION="/dev/nvme0n1p2"
    SPEED="NVMe (3.2 GB/s)"
elif [ -b /dev/sda1 ]; then
    PARTITION="/dev/sda1"
    SPEED="SCSI (~2.5 GB/s)"
else
    echo "NUKE-9100 NOT DETECTED"
    exit 1
fi

# Demounten falls nötig
umount $MOUNTPOINT 2>/dev/null || true

# Volume-Name setzen (falls nicht schon da)
if command -v fatlabel >/dev/null; then
    fatlabel $PARTITION "NUKE-9100" 2>/dev/null || true
elif command -v mlabel >/dev/null; then
    mlabel -i $PARTITION ::NUKE-910KE-9100 2>/dev/null || true
fi

# Mounten
mkdir -p $MOUNTPOINT
mount $PARTITION $MOUNTPOINT
chown -R $SUDO_USER:$SUDO_USER $MOUNTPOINT

# EPIC BOOT MESSAGE
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║             NUKE-9100 ACTIVATED                ║"
echo "║  4.00 TB | $SPEED  ║"
echo "║  $MOUNTPOINT → WARHEAD LOADED           ║"
echo "╚════════════════════════════════════════════════╝"
echo "      DROP THE BEAT.     3.2 GB/s ARMED"
echo ""
EOF

# Ausführbar machen
chmod +x /home/caesar/.scripts/system/disk/mount_nuke-9100.sh
