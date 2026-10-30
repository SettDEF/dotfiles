#!/usr/bin/env bash
# @every 600  (disk headroom and failed units change slowly)
# Filesystem headroom and failed units.
#
# Written after a machine froze hard with BTRFS throwing `-28` (ENOSPC) — the
# root filesystem had crept to 97% while /, /var and /home all shared it. The
# freeze looked like a hardware fault for days.
#
# btrfs matters here: it needs slack for metadata and copy-on-write, so it
# misbehaves well before a traditional filesystem would.
#
# @option crit_pct int 95 "Critical when a filesystem is this full (%)"
# @option warn_pct int 90 "Warning when a filesystem is this full (%)"
# @option btrfs_slack_pct int 85 "btrfs low-slack note from (%)"
# @option skip_mounts text "" "Mount points to ignore (space-separated)"
set -uo pipefail
CRIT=${VITALS_OPT_CRIT_PCT:-95}
WARN=${VITALS_OPT_WARN_PCT:-90}
SLACK=${VITALS_OPT_BTRFS_SLACK_PCT:-85}
SKIP=" ${VITALS_OPT_SKIP_MOUNTS:-} "

# Report each real filesystem ONCE PER DEVICE. On btrfs, /, /home, /var and
# /.snapshots are usually subvolumes of a single device — reporting each as a
# separate "almost full" finding turns one problem into four identical alarms,
# which is exactly the noise that trains you to ignore the panel.
seen_devs=""
while read -r src target fstype pcent avail; do
    [ -z "${target:-}" ] && continue
    case "$SKIP" in *" $target "*) continue ;; esac
    # Read-only images (a mounted AppImage is always 100% "full") are not disks.
    case "$fstype" in *.AppImage|fuse.appimage*) continue ;; esac
    case " $seen_devs " in *" $src "*) continue ;; esac
    seen_devs="$seen_devs $src"

    key=$(echo "$target" | tr '/' '_' | sed 's/^_$/root/; s/^_//')
    n=${pcent%\%}
    echo "fs_${key}_used_pct=$n"
    echo "fs_${key}_avail=$avail"
    if [ "${n:-0}" -ge "$CRIT" ]; then
        echo "fs_${key}_critical=yes"
    elif [ "${n:-0}" -ge "$WARN" ]; then
        echo "fs_${key}_warn=yes"
    fi
    [ "$fstype" = "btrfs" ] && [ "${n:-0}" -ge "$SLACK" ] && echo "fs_${key}_btrfs_low_slack=yes"
done < <(/usr/bin/df -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x fuse.squashfuse -x iso9660 -x overlay --output=source,target,fstype,pcent,avail 2>/dev/null | tail -n +2)

# ENOSPC and I/O errors the kernel logged this boot — the fingerprint of the
# freeze above.
e=$(journalctl -k -b --no-pager 2>/dev/null | grep -ciE "BTRFS error|No space left|I/O error" || true)
[ "${e:-0}" -gt 0 ] && echo "fs_kernel_errors=$e"

# Coredumps: both a symptom of crash loops and a consumer of /var.
if command -v coredumpctl >/dev/null 2>&1; then
    c=$(coredumpctl list --since today --no-pager 2>/dev/null | grep -c . || true)
    [ "${c:-0}" -gt 1 ] && echo "coredumps_today=$(( c - 1 ))"
fi

# Failed units, system and user.
sf=$(systemctl --failed --no-legend --no-pager 2>/dev/null | grep -c . || true)
uf=$(systemctl --user --failed --no-legend --no-pager 2>/dev/null | grep -c . || true)
echo "units_failed_system=${sf:-0}"
echo "units_failed_user=${uf:-0}"

exit 0
