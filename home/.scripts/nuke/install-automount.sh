#!/usr/bin/env bash
# Mount the NUKE-9100 drive at /mnt/nuke9100 whenever it is plugged in.
#   fstab: noauto (never waited on at boot, no automount stat stalls when absent)
#   udev:  the partition appearing starts mnt-nuke9100.mount
# fstab mounts are bound to their device, so unplugging unmounts it.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

UUID=38C6CB58C6CB14D2
LINE="UUID=$UUID  /mnt/nuke9100  ntfs-3g  noauto,nofail,x-systemd.device-timeout=5s,x-systemd.mount-timeout=20s,uid=1000,gid=1000,umask=022,noatime,windows_names  0  0"

cp /etc/fstab "/etc/fstab.bak-$(date +%s)"
grep -v "$UUID" /etc/fstab > /etc/fstab.new
echo "$LINE" >> /etc/fstab.new
mv /etc/fstab.new /etc/fstab

cat > /etc/udev/rules.d/61-nuke9100-mount.rules <<RULE
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$UUID", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-nuke9100.mount"
RULE

mkdir -p /mnt/nuke9100
systemctl daemon-reload
udevadm control --reload
[ -e "/dev/disk/by-uuid/$UUID" ] && systemctl start mnt-nuke9100.mount
findmnt /mnt/nuke9100 || echo "not plugged in; it will mount on plug-in"
