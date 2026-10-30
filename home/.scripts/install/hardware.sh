#!/bin/bash

source "$(dirname $0)/../utils.sh"

# Make the function keys on the keyboard default over media keys.
# (This is currently specific to my keychron keyboard)
FILE=/etc/modprobe.d/hid_apple.conf
sudo touch $FILE
sudo sh -c "echo 'options hid_apple fnmode=2' >> $FILE"

# Bluetooth.
systemctl enable bluetooth.service
# Paired devices reconnect on their own: an Xbox pad that lost its pairing
# (console/USB) may re-pair, connects are answered fast, drops are retried.
# The experimental "rap" (ranging) profile fails on every LE connect: disabled.
bt_set() { sudo sed -i -E "0,/^[#[:space:]]*$1[[:space:]]*=.*/s//$1 = $2/" /etc/bluetooth/main.conf; }
bt_set AutoEnable true # Enable on startup.
bt_set JustWorksRepairing always
bt_set FastConnectable true
bt_set ReconnectAttempts 7
bt_set ReconnectIntervals 1,2,4,8,16,32,64
sudo mkdir -p /etc/systemd/system/bluetooth.service.d
printf '[Service]\nExecStart=\nExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=rap\n' \
    | sudo tee /etc/systemd/system/bluetooth.service.d/noplugin-rap.conf > /dev/null
sudo systemctl daemon-reload
systemctl restart bluetooth.service

# Sound stuff.
# Prevent the crackling sound.
sudo sed -i 's/load-module module-udev-detect/load-module module-udev-detect tsched=0/g' /etc/pulse/default.pa

# Power management.
systemctl enable tlp.service
systemctl mask systemd-rfkill.service
systemctl mask systemd-rfkill.socket
systemctl start tlp.service
sudo tlp start

# Setup optimus manager.
if $NVIDIA_GPU; then
    sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /etc/gdm/custom.conf
    sudo touch /etc/optimus-manager/optimus-manager.conf 
    sudo sh -c "echo '[optimus]' >> /etc/optimus-manager/optimus-manager.conf" 
    sudo sh -c "echo 'startup_mode=nvidia' >> /etc/optimus-manager/optimus-manager.conf" 
    systemctl enable optimus-manager
    systemctl start optimus-manager &
fi

# Virtualization setup (QEMU/KVM/libvirt)
systemctl enable --now libvirtd.socket
systemctl enable --now libvirtd
VM_USER="${SUDO_USER:-$USER}"
usermod -aG libvirt "$VM_USER"

# ASUS ROG Flow Z13 / Laptop Specific Setup (asusctl, supergfxctl, iio-sensor-proxy)
if grep -qi "asus" /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null; then
    echo "ASUS system detected. Setting up asusd, supergfxd, and iio-sensor-proxy..."
    systemctl enable --now asusd
    systemctl enable --now supergfxd
    systemctl enable --now iio-sensor-proxy
fi


