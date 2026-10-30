#!/bin/bash

# Arch Linux Kernel Update Script
# Safely updates the linux package, ensures /boot is mounted, installs efibootmgr,
# regenerates initramfs, and updates GRUB to prevent boot failures.

# Configuration
CURRENT_KERNEL="$(uname -r)" # Current kernel from uname -r
SCRIPTS_DIR="/home/$SUDO_USER/.scripts"
BOOT_PARTITION="/dev/sdb1" # From lsblk, /boot partition
BOOT_MOUNT="/boot" # Mount point for /boot
TIME_STAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/kernel_update_$TIME_STAMP.log"
USERNAME="$SUDO_USER" # Get the username of the sudo-calling user

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Prompt for user confirmation
confirm() {
    local prompt="$1"
    read -p "$prompt (y/N): " choice
    [[ "$choice" =~ ^[Yy]$ ]]
}

# Ensure directory is writable
check_writable() {
    local dir="$1"
    if [[ ! -w "$dir" ]]; then
        log "Error: Directory $dir is not writable"
        exit 1
    fi
}

# Check if /boot is mounted
check_boot_mounted() {
    log "Checking if $BOOT_MOUNT is mounted"
    if ! mountpoint -q "$BOOT_MOUNT"; then
        log "Warning: $BOOT_MOUNT is not mounted"
        if confirm "Mount $BOOT_PARTITION on $BOOT_MOUNT now?"; then
            mkdir -p "$BOOT_MOUNT"
            mount "$BOOT_PARTITION" "$BOOT_MOUNT" || { log "Failed to mount $BOOT_PARTITION on $BOOT_MOUNT"; exit 1; }
            log "$BOOT_PARTITION mounted on $BOOT_MOUNT"
        else
            log "Error: $BOOT_MOUNT must be mounted to proceed"
            exit 1
        fi
    else
        log "$BOOT_MOUNT is mounted"
    fi
}

# Check /etc/fstab for /boot
check_fstab() {
    log "Checking /etc/fstab for $BOOT_PARTITION"
    boot_uuid=$(blkid -s UUID -o value "$BOOT_PARTITION")
    if [[ -z "$boot_uuid" ]]; then
        log "Error: Could not determine UUID for $BOOT_PARTITION"
        exit 1
    fi
    if grep -q "$boot_uuid" /etc/fstab || grep -q "$BOOT_PARTITION" /etc/fstab; then
        log "/etc/fstab includes $BOOT_MOUNT entry"
    else
        log "Warning: /etc/fstab does not include $BOOT_PARTITION for $BOOT_MOUNT"
        if confirm "Add $BOOT_PARTITION to /etc/fstab?"; then
            echo "UUID=$boot_uuid $BOOT_MOUNT vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2" >> /etc/fstab
            log "Added $BOOT_PARTITION to /etc/fstab"
        else
            log "Warning: /etc/fstab not updated; manual configuration required"
        fi
    fi
}

# Check disk space
check_disk_space() {
    log "Checking disk space for / and $BOOT_MOUNT"
    root_space=$(df -m / | tail -1 | awk '{print $4}')
    boot_space=$(df -m "$BOOT_MOUNT" | tail -1 | awk '{print $4}')
    if [[ "$root_space" -lt 500 ]]; then
        log "Warning: Low disk space on / ($root_space MB available). Recommended: >500 MB"
    else
        log "Sufficient disk space on / ($root_space MB available)"
    fi
    if [[ "$boot_space" -lt 100 ]]; then
        log "Error: Low disk space on $BOOT_MOUNT ($boot_space MB available). Required: >100 MB"
        exit 1
    else
        log "Sufficient disk space on $BOOT_MOUNT ($boot_space MB available)"
    fi
}

# Compare kernel versions
compare_versions() {
    local current="$1"
    local repo="$2"
    if [[ "$current" == "$repo" ]]; then
        return 0 # Equal
    fi
    if [[ $(echo -e "$current\n$repo" | sort -V | tail -1) == "$repo" ]]; then
        return 1 # Repo is newer
    else
        return 2 # Current is newer or error
    fi
}

# Update kernel
update_kernel() {
    log "Updating kernel to $repo_version"
    pacman -Syy || { log "Failed to sync package database"; exit 1; }
    pacman -S --noconfirm linux && log "Installed kernel $repo_version" || { log "Failed to install kernel"; exit 1; }
    mkinitcpio -P || { log "Failed to regenerate initramfs"; exit 1; }
    log "Initramfs regenerated"
    grub-install --target=x86_64-efi --efi-directory="$BOOT_MOUNT" --bootloader-id=GRUB || { log "Failed to reinstall GRUB"; exit 1; }
    grub-mkconfig -o "$BOOT_MOUNT/grub/grub.cfg" || { log "Failed to update GRUB configuration"; exit 1; }
    log "GRUB updated"
}

# Main function
main() {
    check_root
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Cannot create log directory $(dirname "$LOG_FILE")"; exit 1; }
    check_writable "$(dirname "$LOG_FILE")"
    
    log "Starting kernel update process"
    
    # Install efibootmgr if missing
    if ! command -v efibootmgr >/dev/null; then
        log "Installing efibootmgr"
        pacman -S --noconfirm efibootmgr || { log "Failed to install efibootmgr"; exit 1; }
        log "efibootmgr installed"
    fi
    
    # Run checks
    check_boot_mounted
    check_fstab
    check_disk_space
    
    # Get repository kernel version
    repo_version=$(pacman -Si linux | grep '^Version' | awk '{print $3}')
    if [[ -z "$repo_version" ]]; then
        log "Error: Failed to retrieve repository kernel version"
        exit 1
    fi
    
    log "Current kernel: $CURRENT_KERNEL"
    log "Repository kernel: $repo_version"
    
    compare_versions "$CURRENT_KERNEL" "$repo_version"
    result=$?
    
    if [[ $result -eq 0 ]]; then
        log "Kernel is up to date ($CURRENT_KERNEL)"
        exit 0
    elif [[ $result -eq 1 ]]; then
        log "Newer kernel available ($repo_version)"
        if confirm "Install kernel update ($repo_version)?"; then
            update_kernel
            if confirm "Reboot now to use the new kernel ($repo_version)?"; then
                log "Rebooting system"
                reboot
            else
                log "Update completed. Please reboot manually to use the new kernel."
            fi
        else
            log "Kernel update skipped"
            exit 0
        fi
    else
        log "Warning: Current kernel ($CURRENT_KERNEL) appears newer than repository ($repo_version)"
        exit 1
    fi
}

main
