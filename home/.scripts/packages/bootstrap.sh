#!/bin/bash

source "$(dirname $0)/../utils.sh"

# Install paru.
git clone https://aur.archlinux.org/paru.git $USER_HOME/.modules/paru/
cd $USER_HOME/.modules/paru/ || exit
makepkg -si
cd $USER_HOME || exit

# Keys.
paru -S archlinux-keyring
sudo pacman-key --init
sudo pacman-key --populate archlinux

# Mirrors.
paru -Syyu reflector rsync
$USER_HOME/.scripts/packages/update_mirrorlist.sh &

# Packages.
$USER_HOME/.scripts/packages/install.sh
