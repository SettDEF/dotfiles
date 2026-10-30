#!/usr/bin/env bash
# Helper script to safely mount the physical Windows partition and start the VM.

# Configuration
WINDOWS_PARTITION="/dev/nvme0n1p3" # Update to your physical Windows partition (e.g. /dev/sda3, /dev/nvme0n1p3)
MOUNT_POINT="/mnt/windows"
VM_NAME="win11-gaming"            # Update to your VM name in virt-manager

# Ensure mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point at $MOUNT_POINT..."
    sudo mkdir -p "$MOUNT_POINT"
fi

# Function to mount the partition
mount_windows() {
    # Check if partition is mounted elsewhere on the host
    local mounted_elsewhere
    mounted_elsewhere=$(findmnt -n -o TARGET "$WINDOWS_PARTITION" | grep -v "^${MOUNT_POINT}$" | head -n 1)
    if [ -n "$mounted_elsewhere" ]; then
        echo "Error: Partition $WINDOWS_PARTITION is already mounted at $mounted_elsewhere."
        notify-send -a "Windows VM" -u critical "Mount Blocked" "Windows drive is already mounted at $mounted_elsewhere"
        exit 1
    fi

    if mountpoint -q "$MOUNT_POINT"; then
        echo "Windows partition is already mounted."
    else
        echo "Mounting $WINDOWS_PARTITION to $MOUNT_POINT using ntfs3..."
        sudo mount -t ntfs3 -o uid=$(id -u),gid=$(id -g),dmask=027,fmask=137 "$WINDOWS_PARTITION" "$MOUNT_POINT"
        if [ $? -eq 0 ]; then
            echo "Successfully mounted."
        else
            echo "Error: Failed to mount Windows partition."
            notify-send -a "Windows VM" -u critical "Mount Failed" "Failed to mount Windows partition. Check if Windows was shutdown cleanly."
            exit 1
        fi
    fi
}

# Function to unmount the partition safely
unmount_windows() {
    # Check if VM is running before unmounting
    if virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
        echo "Error: Cannot unmount while the VM is running."
        notify-send -a "Windows VM" -u critical "Unmount Blocked" "Cannot unmount the partition while the VM is running."
        exit 1
    fi

    if mountpoint -q "$MOUNT_POINT"; then
        echo "Unmounting Windows partition safely..."
        sudo umount "$MOUNT_POINT"
        echo "Unmounted."
    else
        echo "Windows partition is not mounted."
    fi
}

case "$1" in
    start)
        # Check if VM is already running
        if virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
            echo "VM '$VM_NAME' is already running. Reattaching viewer..."
            notify-send -a "Windows VM" "VM already running" "Reattaching display viewer..."
            virt-viewer --connect qemu:///system --attach "$VM_NAME" &
            exit 0
        fi

        mount_windows
        echo "Starting VM '$VM_NAME'..."
        notify-send -a "Windows VM" "Booting..." "Starting Windows Environment VM..."
        if virsh --connect qemu:///system start "$VM_NAME"; then
            virt-viewer --connect qemu:///system --attach "$VM_NAME" &
        else
            echo "Error: Failed to start VM."
            notify-send -a "Windows VM" -u critical "Boot Failed" "Failed to start the virtual machine."
            exit 1
        fi
        ;;
    stop)
        # Check if VM is running
        if ! virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null | grep -q "running"; then
            echo "VM '$VM_NAME' is not running."
            exit 0
        fi

        echo "Stopping VM '$VM_NAME'..."
        notify-send -a "Windows VM" "Shutting down..." "Sending graceful shutdown signal to Windows..."
        if virsh --connect qemu:///system shutdown "$VM_NAME"; then
            # Wait for VM to stop and then safely unmount
            echo "Waiting for VM to stop..."
            while virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null | grep -q "running"; do
                sleep 1
            done
            unmount_windows
            notify-send -a "Windows VM" "Offline" "Windows VM stopped and drive safely unmounted."
        else
            echo "Error: Failed to send shutdown signal."
            notify-send -a "Windows VM" -u critical "Shutdown Failed" "Failed to send shutdown signal."
            exit 1
        fi
        ;;
    mount)
        mount_windows
        ;;
    umount|unmount)
        unmount_windows
        ;;
    *)
        echo "Usage: $0 {start|stop|mount|umount}"
        echo "  start   - Mounts Windows partition and launches the VM"
        echo "  stop    - Gracefully shuts down the VM and unmounts the partition"
        echo "  mount   - Mounts the Windows partition on the Arch host"
        echo "  umount  - Safely unmounts the Windows partition"
        exit 1
        ;;
esac
