#!/bin/bash

# Arch Linux Dotfiles and Environment Setup Script
# Run as a regular user with sudo privileges

set -e

echo "Setting up Arch Linux environment..."

# Define dotfiles repository
DOTFILES_REPO="https://github.com/caesarium/dotfiles.git"
DOTFILES_DIR="$HOME/.config/dotfiles"

# Update system
sudo pacman -Syu --noconfirm

# Install packages
sudo pacman -S --noconfirm \
    base-devel git vim networkmanager sudo zsh firefox \
    tmux neovim i3-wm kitty mpv ncmpcpp awesome btop \
    dunst htop picom ranger redshift rofi surfraw timewarrior \
    vifm wezterm zathura darkman xdg-desktop-portal xdg-desktop-portal-gtk \
    todo-txt gnupg mpd
    # ecryptfs-utils  # Uncomment for ~/.private (run ecryptfs-setup-private manually)

# Enable NetworkManager
sudo systemctl enable --now NetworkManager

# Create home directories
echo "Creating home directories..."
mkdir -p ~/coding/{projects,scripts}
mkdir -p ~/.wallpapers
mkdir -p ~/Pictures
mkdir -p ~/Documents
mkdir -p ~/Downloads
mkdir -p ~/todos
mkdir -p ~/"Bitwig Studio"/{Projects,Presets}
mkdir -p ~/.private
touch ~/.secret  # Created as a file for sensitive data
chmod 600 ~/.secret

# Install paru
if ! command -v paru &> /dev/null; then
    echo "Installing paru..."
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
fi

# Setup chaotic-aur
if ! grep -q "chaotic-aur" /etc/pacman.conf; then
    echo "Setting up chaotic-aur..."
    sudo pacman-key --recv-key 3056513887B78AEB
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
    sudo pacman -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst
    echo "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
    echo "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syyu --noconfirm
fi

# Setup archstrike
if ! grep -q "archstrike" /etc/pacman.conf; then
    echo "Setting up archstrike..."
    echo "[archstrike]" | sudo tee -a /etc/pacman.conf
    echo "Server = https://mirror.archstrike.org/x86_64/" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syyu --noconfirm archstrike-keyring archstrike-mirrorlist
fi

# Install zplug
if [ ! -d ~/.zplug ]; then
    echo "Installing zplug..."
    curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

# Clone and setup dotfiles
echo "Setting up dotfiles from $DOTFILES_REPO..."
if [ -n "$DOTFILES_REPO" ]; then
    if [ ! -d "$DOTFILES_DIR" ]; then
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    cd "$DOTFILES_DIR"

    # Symlink dotfiles
    for file in zshrc zshenv p10k.zsh tmux.conf vimrc gitconfig xbindkeysrc Xmodmap secret; do
        if [ -f "$file" ]; then
            ln -sf "$DOTFILES_DIR/$file" "$HOME/.$file"
            echo "Linked ~/.$file"
        fi
    done

    # Copy .config/ dirs
    for dir in awesome btop darkman dunst function htop i3 kitty mpv ncmpcpp nvim picom ranger redshift rofi surfraw timewarrior tmux vifm vim wezterm zathura zsh; do
        if [ -d "config/$dir" ]; then
            mkdir -p "$HOME/.config/$dir"
            cp -r "config/$dir/." "$HOME/.config/$dir/"
            echo "Copied config/$dir to ~/.config/$dir"
        fi
    done

    # Special case: mimeapps.list, user-dirs.dirs
    for file in mimeapps.list user-dirs.dirs; do
        if [ -f "config/$file" ]; then
            cp "config/$file" "$HOME/.config/$file"
            echo "Copied config/$file to ~/.config/$file"
        fi
    done

    # PulseAudio configs
    if [ -d "config/pulse" ]; then
        mkdir -p "$HOME/.config/pulse"
        for file in daemon.conf client.conf default.pa; do
            if [ -f "config/pulse/$file" ]; then
                cp "config/pulse/$file" "$HOME/.config/pulse/$file"
                echo "Copied config/pulse/$file to ~/.config/pulse/$file"
            fi
        done
    fi
else
    echo "No dotfiles repo specified. Setting up minimal configs..."
    cat <<EOT > ~/.zshrc
source ~/.zplug/init.zsh
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "romkatv/powerlevel10k", as:theme
if ! zplug check; then
    zplug install
fi
zplug load
EOT
    mkdir -p ~/.config/darkman
    cat <<EOT > ~/.config/darkman/config.yaml
lat: 40.7
lng: -74.0
usegeoclue: false
portal: true
dbusserver: true
EOT
fi

# Set zsh as default shell
chsh -s /bin/zsh

# Install wallpapers
echo "Installing wallpapers..."
git clone https://github.com/archcraft-os/archcraft-wallpapers /tmp/wallpapers
cp /tmp/wallpapers/wallpapers/* ~/.wallpapers/
rm -rf /tmp/wallpapers

# Setup coding repos
echo "Cloning coding repos..."
git clone https://github.com/ohmyzsh/ohmyzsh.git ~/coding/oh-my-zsh
git clone https://github.com/xero/figlet-fonts.git ~/coding/figlet-fonts

# Setup darkman
systemctl --user enable --now darkman.service

# Install xdg-desktop-portal
mkdir -p ~/.config/xdg-desktop-portal
cat <<EOT > ~/.config/xdg-desktop-portal/portals.conf
[preferred]
org.freedesktop.impl.portal.Settings=darkman
EOT
systemctl --user restart xdg-desktop-portal.service

# Setup todos
touch ~/todos.txt

echo "Setup complete! Run 'p10k configure' if needed."
echo "Edit ~/.config/darkman/config.yaml for your lat/lng."
echo "If using ecryptfs, run 'ecryptfs-setup-private' manually."
