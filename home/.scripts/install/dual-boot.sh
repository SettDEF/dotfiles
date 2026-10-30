#!/bin/bash

read -e -i "/boot/efi" -p "EFI directory: " EFIDIRECTORY
grub-install --target=x86_64-efi --efi-directory="/dev/nvme0n1p1" --bootloader-id=GRUB
