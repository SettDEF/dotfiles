#!/bin/bash
# libinput quirks for the ROG Flow Z13 (GZ302) + MX Master 3S.
# Quirks load at compositor start: log out and back in after running.
#
# - Hex IDs must be UPPERCASE: one unparsable section makes libinput load no
#   quirks at all.
# - Keyboard cover (USB 0B05:1A30) pinned to external, and the Asus WMI
#   tablet-mode switch marked unreliable: it reports "tablet" with the cover
#   attached, and libinput then disables the cover's keyboard and touchpad.

source "$(dirname "$0")/../utils.sh"

FILE=/etc/libinput/local-overrides.quirks
sudo mkdir -p /etc/libinput
[ -f "$FILE" ] && sudo cp -a "$FILE" "$FILE.bak"
sudo tee "$FILE" > /dev/null <<'EOF'
[Logitech MX Master 3S Bluetooth]
MatchVendor=0x046D
MatchProduct=0xB034
AttrEventCode=-REL_WHEEL_HI_RES;-REL_HWHEEL_HI_RES;

[ASUS Z13 GZ302EA keyboard cover]
MatchUdevType=keyboard
MatchBus=usb
MatchVendor=0x0B05
MatchProduct=0x1A30
AttrKeyboardIntegration=external

[ASUS Z13 GZ302 tablet mode switch]
MatchName=Asus WMI hotkeys
ModelTabletModeSwitchUnreliable=1
EOF
libinput quirks validate && echo "libinput quirks valid — log out and back in."

# Keyboard cover reset: unbind + rebind its USB device, the software version of
# detaching and reattaching the cover. Its keyboard/touchpad sometimes get into
# a state where the first click after a modifier is lost; a reattach clears it.
# Bound to Super+Ctrl+Escape (lua/local.lua); passwordless for this helper only.
sudo tee /usr/local/bin/z13-cover-reset > /dev/null <<'SH'
#!/bin/sh
# Reconnect the ROG Flow Z13 keyboard cover (USB 0B05:1A30).
for d in /sys/bus/usb/devices/*; do
    [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = "0b05:1a30" ] || continue
    id=$(basename "$d")
    echo "$id" > /sys/bus/usb/drivers/usb/unbind
    sleep 1
    echo "$id" > /sys/bus/usb/drivers/usb/bind
done
SH
sudo chmod 755 /usr/local/bin/z13-cover-reset
RULE=$(mktemp)
echo "${SUDO_USER:-$USER} ALL=(root) NOPASSWD: /usr/local/bin/z13-cover-reset" > "$RULE"
if sudo visudo -cf "$RULE" > /dev/null; then
    sudo install -m 0440 -o root -g root "$RULE" /etc/sudoers.d/z13-cover-reset
    echo "cover reset ready: Super+Ctrl+Escape"
else
    echo "sudoers rule failed validation — not installed"
fi
rm -f "$RULE"
