#!/bin/bash
# boot.sh — a faster boot, chosen from a checklist (whiptail; fzf without it). Any laptop, any
# distro: GRUB (Arch, Debian/Ubuntu, Fedora), systemd-boot and Limine; mkinitcpio and dracut;
# NetworkManager and systemd-networkd. Steps only show when they apply; machines/<family>.sh adds
# the laptop's own (named from its firmware, e.g. rog-flow-z13, thinkpad-x1-carbon-gen-11).
#
# Usage: boot.sh            the checklist (space toggles, Enter applies)
#        boot.sh --all      the steps marked on, no questions (the install)
#        boot.sh --dry-run  with either: show the commands, change nothing
# Not here, only in the firmware setup (F2 at power on): Fast Boot on, network/PXE boot off.

source "$(dirname "$0")/../utils.sh"

DRY=false; ALL=false
for a in "$@"; do
    case $a in
        --dry-run) DRY=true ;;
        --all) ALL=true ;;
        *) echo "usage: boot.sh [--all] [--dry-run]"; exit 2 ;;
    esac
done
export DRY
run() { if $DRY; then echo "  would run: $*"; else sudo "$@"; fi; }
GRUB=/etc/default/grub
grub_get() { sed -n "s/^$1=//p" "$GRUB" 2>/dev/null | tr -d '"'; }
grub_set() {
    if grep -q "^$1=" "$GRUB"; then run sed -i "s|^$1=.*|$1=\"$2\"|" "$GRUB"
    else run sed -i "\$a $1=\"$2\"" "$GRUB"; fi
    GRUB_CHANGED=true
}
# the distro's way to rebuild grub.cfg
grub_update() {
    if command -v update-grub >/dev/null; then run update-grub
    elif command -v grub2-mkconfig >/dev/null; then run grub2-mkconfig -o "$( [ -d /boot/grub2 ] && echo /boot/grub2 || echo /boot/grub)/grub.cfg"
    else run grub-mkconfig -o /boot/grub/grub.cfg; fi
}
# systemd-boot's and Limine's menu files, where the distro put them
SDBOOT=$(ls /boot/loader/loader.conf /efi/loader/loader.conf /boot/efi/loader/loader.conf 2>/dev/null | head -1)
LIMINE=$(ls /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /efi/limine.conf 2>/dev/null | head -1)
# their menu wait (empty when there is none: never a read from the terminal)
sd_timeout()  { [ -n "$SDBOOT" ] && awk '/^timeout/{print $2}' "$SDBOOT"; }
lim_timeout() { [ -n "$LIMINE" ] && sed -nE 's/^timeout:? *//p' "$LIMINE" | head -1; }
GRUB_CHANGED=false; INITRD_CHANGED=false

# ── the steps: id, on by default, what it does; avail_<id> says if it applies, do_<id> does it ──
STEPS=(
    "grub1|on|GRUB menu waits 1 s instead of $(grub_get GRUB_TIMEOUT) s (a key still stops it)  ~4 s"
    "sdboot1|on|systemd-boot menu waits 1 s instead of $(sd_timeout) s (a key still stops it)"
    "limine1|on|Limine menu waits 1 s instead of $(lim_timeout) s (a key still stops it)"
    "grubhide|off|GRUB menu hidden, Esc shows it (a dual boot picks Linux without asking)"
    "quiet|on|kernel quiet, loglevel=3 (printing every message is slow)  <1 s"
    "libvirt|on|libvirtd only when a VM tool asks, not at every boot  ~0.8 s"
    "waitonline|off|no waiting for the network at boot (only $(systemctl list-dependencies --reverse --plain network-online.target 2>/dev/null | tail -n +2 | wc -l) units ask for it)  ~5 s off the total"
    "lz4|off|initramfs packed with lz4: unpacks faster, about twice the size on /boot"
)

avail_grub1()      { [ -f "$GRUB" ] && [ "$(grub_get GRUB_TIMEOUT)" -gt 1 ] 2>/dev/null; }
do_grub1()         { grub_set GRUB_TIMEOUT 1; }
avail_grubhide()   { [ -f "$GRUB" ] && [ "$(grub_get GRUB_TIMEOUT_STYLE)" != hidden ]; }
do_grubhide()      { grub_set GRUB_TIMEOUT_STYLE hidden; [ "$(grub_get GRUB_TIMEOUT)" -gt 1 ] 2>/dev/null && grub_set GRUB_TIMEOUT 1; }
avail_quiet() {
    [ -f "$GRUB" ] || return 1
    local l; l=$(grub_get GRUB_CMDLINE_LINUX_DEFAULT)
    echo "$l" | grep -qE '(^| )loglevel=[4-7]( |$)' || ! echo "$l" | grep -qw quiet
}
do_quiet() {
    local l; l=$(grub_get GRUB_CMDLINE_LINUX_DEFAULT | sed -E 's/(^| )loglevel=[0-9]//; s/  +/ /g; s/^ //; s/ $//')
    echo "$l" | grep -qw quiet || l="quiet $l"
    grub_set GRUB_CMDLINE_LINUX_DEFAULT "$l loglevel=3"
}
avail_libvirt()    { systemctl list-unit-files libvirtd.socket &>/dev/null && systemctl is-enabled -q libvirtd.service 2>/dev/null; }
do_libvirt()       { run systemctl disable libvirtd.service; run systemctl enable libvirtd.socket; }
avail_sdboot1()    { [ -n "$SDBOOT" ] && [ "$(sd_timeout)" != 1 ] && [ "$(sd_timeout)" != 0 ]; }
do_sdboot1() {
    if grep -q '^timeout' "$SDBOOT"; then run sed -i 's/^timeout.*/timeout 1/' "$SDBOOT"
    else run sed -i '$a timeout 1' "$SDBOOT"; fi
}
avail_limine1()    { [ "$(lim_timeout)" -gt 1 ] 2>/dev/null; }
do_limine1()       { run sed -i -E 's/^(timeout:? *)[0-9]+/\11/' "$LIMINE"; }
# the network wait of whichever network manager runs here
WAIT_ONLINE=$(for u in NetworkManager-wait-online.service systemd-networkd-wait-online.service; do systemctl is-enabled -q "$u" 2>/dev/null && echo "$u"; done | head -1)
avail_waitonline() { [ -n "$WAIT_ONLINE" ]; }
do_waitonline()    { run systemctl disable "$WAIT_ONLINE"; }
# mkinitcpio (Arch) or dracut (Fedora, openSUSE, Void …); lz4 must be installed for either
avail_lz4() {
    command -v lz4 >/dev/null || return 1
    if [ -f /etc/mkinitcpio.conf ]; then ! grep -qE '^COMPRESSION="?lz4' /etc/mkinitcpio.conf
    elif command -v dracut >/dev/null; then ! grep -rqs 'compress="lz4"' /etc/dracut.conf /etc/dracut.conf.d/
    else return 1; fi
}
do_lz4() {
    if [ -f /etc/mkinitcpio.conf ]; then
        if grep -qE '^#?COMPRESSION="?lz4' /etc/mkinitcpio.conf; then run sed -i -E 's/^#?COMPRESSION="?lz4"?/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
        else run sed -i '$a COMPRESSION="lz4"' /etc/mkinitcpio.conf; fi
    else
        if $DRY; then echo "  would write: compress=\"lz4\" to /etc/dracut.conf.d/90-lz4.conf"
        else echo 'compress="lz4"' | sudo tee /etc/dracut.conf.d/90-lz4.conf >/dev/null; fi
    fi
    INITRD_CHANGED=true
}
# the initramfs rebuilt the distro's way
initrd_update() {
    if command -v mkinitcpio >/dev/null; then run mkinitcpio -P
    elif command -v dracut >/dev/null; then run dracut --regenerate-all --force
    elif command -v update-initramfs >/dev/null; then run update-initramfs -u -k all; fi
}

# this laptop's own steps (machines/<family>.sh defines MACHINE_STEPS, avail_*, do_*)
MACHINE_FILE="$(dirname "$0")/machines/${MACHINE}.sh"
[ -n "$MACHINE" ] && [ -f "$MACHINE_FILE" ] && source "$MACHINE_FILE" && STEPS+=("${MACHINE_STEPS[@]}")

# ── what applies here ─────────────────────────────────────────────────
ids=(); ons=(); texts=()
for s in "${STEPS[@]}"; do
    IFS='|' read -r id on text <<< "$s"
    "avail_$id" 2>/dev/null || continue
    ids+=("$id"); ons+=("$on"); texts+=("$text")
done
if [ ${#ids[@]} -eq 0 ]; then
    echo "boot: nothing left to speed up here (${MACHINE:-unknown machine})"
    exit 0
fi

# ── the choice ────────────────────────────────────────────────────────
chosen=()
if $ALL; then
    for i in "${!ids[@]}"; do [ "${ons[$i]}" = on ] && chosen+=("${ids[$i]}"); done
elif [ -t 0 ] && command -v whiptail >/dev/null; then
    args=()
    for i in "${!ids[@]}"; do args+=("${ids[$i]}" "${texts[$i]}" "${ons[$i]^^}"); done
    out=$(whiptail --title "Faster boot (${MACHINE:-this machine})" --separate-output \
        --checklist "Space toggles, Enter applies.$($DRY && echo ' Dry run: nothing changes.')" \
        20 100 ${#ids[@]} "${args[@]}" 3>&1 1>&2 2>&3) || { echo "cancelled"; exit 0; }
    mapfile -t chosen <<< "$out"
elif command -v fzf >/dev/null; then
    out=$(for i in "${!ids[@]}"; do printf '%s\t%s\n' "${ids[$i]}" "${texts[$i]}"; done |
        fzf --multi --with-nth=2 --delimiter='\t' --prompt="Tab picks, Enter applies> " | cut -f1)
    mapfile -t chosen <<< "$out"
else
    for i in "${!ids[@]}"; do
        read -rp "${texts[$i]}? [$([ "${ons[$i]}" = on ] && echo Y/n || echo y/N)] " a
        case ${a:-${ons[$i]}} in y|Y|on) chosen+=("${ids[$i]}") ;; esac
    done
fi

# ── doing it ──────────────────────────────────────────────────────────
for id in "${chosen[@]}"; do
    [ -z "$id" ] && continue
    for i in "${!ids[@]}"; do [ "${ids[$i]}" = "$id" ] && echo "• ${texts[$i]}"; done
    "do_$id"
done
$GRUB_CHANGED && grub_update
$INITRD_CHANGED && initrd_update
[ ${#chosen[@]} -gt 0 ] && [ -n "${chosen[0]}" ] && echo "done: reboot, then 'systemd-analyze' to compare"
