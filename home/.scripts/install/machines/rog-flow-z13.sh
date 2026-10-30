#!/bin/bash
# rog-flow-z13.sh — the ASUS ROG Flow Z13 (GZ302) only: its steps in ../boot.sh's checklist
# (sourced there; run, grub_get and grub_set come from it).
# Firmware (by hand, F2 at power on): Boot → Fast Boot on; it took 9.2 s before GRUB (2026-10-28).

MACHINE_STEPS=(
    "z13nvme|on|Z13: NVMe deepest power state off (nvme_core.default_ps_max_latency_us=0; it dropped the drive)"
)

avail_z13nvme() { [ -f "$GRUB" ] && ! grub_get GRUB_CMDLINE_LINUX_DEFAULT | grep -q 'nvme_core.default_ps_max_latency_us=0'; }
do_z13nvme()    { grub_set GRUB_CMDLINE_LINUX_DEFAULT "$(grub_get GRUB_CMDLINE_LINUX_DEFAULT) nvme_core.default_ps_max_latency_us=0"; }
