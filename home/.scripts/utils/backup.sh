#!/bin/bash

# Improved Backup Script for Dotfiles and Important Files

set -e

# Define backup directory with timestamp
BACKUP_DIR="/home/$USER/backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_TAR="$BACKUP_DIR.tar.gz"
mkdir -p "$BACKUP_DIR"

# List of important files and directories to backup
FILES_TO_BACKUP=(
    # Core dotfiles
    "$HOME/.zshrc"
    "$HOME/.zshenv"
    "$HOME/.zsh_history"
    "$HOME/.p10k.zsh"
    "$HOME/.tmux.conf"
    "$HOME/.vimrc"
    "$HOME/.viminfo"
    "$HOME/.gitconfig"
    "$HOME/.xbindkeysrc"
    "$HOME/.Xmodmap"
    "$HOME/.secret"

    # Custom scripts
    "$HOME/.scripts"

    # System config templates (deployed into /etc by install/links.sh
    # and install/greeter.sh). Holds greeter source + any future system
    # config that needs to survive a reinstall.
    "$HOME/.etc"

    # Config directories
    "$HOME/.config/awesome"
    "$HOME/.config/btop"
    "$HOME/.config/darkman"
    "$HOME/.config/dunst"
    "$HOME/.config/function"
    "$HOME/.config/htop"
    "$HOME/.config/i3"
    "$HOME/.config/kitty"
    "$HOME/.config/mpv"
    "$HOME/.config/ncmpcpp"
    "$HOME/.config/nvim"
    "$HOME/.config/picom"
    "$HOME/.config/ranger"
    "$HOME/.config/redshift"
    "$HOME/.config/rofi"
    "$HOME/.config/surfraw"
    "$HOME/.config/timewarrior"
    "$HOME/.config/tmux"
    "$HOME/.config/vifm"
    "$HOME/.config/vim"
    "$HOME/.config/wezterm"
    "$HOME/.config/zathura"
    "$HOME/.config/zsh"
    "$HOME/.config/mimeapps.list"
    "$HOME/.config/user-dirs.dirs"
    "$HOME/.config/dotfiles"

    # PulseAudio configs
    "$HOME/.config/pulse/daemon.conf"
    "$HOME/.config/pulse/client.conf"
    "$HOME/.config/pulse/default.pa"

    # Important user directories
    "$HOME/Bitwig Studio/Presets"
    "$HOME/Bitwig Studio/Projects"
    "$HOME/.torrent"
    "$HOME/.wallpapers"
    "$HOME/coding"
    "$HOME/Pictures"
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/todos"

    # Zplug data
    "$HOME/.zplug"
)

# Check disk space (5GB for safety)
check_disk_space() {
    local required_space_mb=5120
    local available_space_mb
    available_space_mb=$(df -m "$HOME" | tail -1 | awk '{print $4}')
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo "Error: Insufficient disk space ($available_space_mb MB available, $required_space_mb MB required)."
        exit 1
    fi
}

# Backup a file or directory
backup_item() {
    local item="$1"
    local dest="$BACKUP_DIR${item#$HOME}"
    if [ -e "$item" ]; then
        mkdir -p "$(dirname "$dest")"
        if [[ "$item" == "$HOME/coding" || "$item" == "$HOME/Bitwig Studio"* ]]; then
            rsync -a --exclude=".git" --exclude="*.wav" --exclude="*.aiff" "$item" "$dest"
        else
            cp -r --preserve=mode,timestamps "$item" "$dest"
        fi
        echo "Backed up $item"
    else
        echo "Warning: $item does not exist, skipping..."
    fi
}

echo "Starting backup to $BACKUP_TAR..."

# Check disk space
check_disk_space

# Backup each item
for item in "${FILES_TO_BACKUP[@]}"; do
    backup_item "$item"
done

# Compress backup
echo "Compressing backup..."
tar -czf "$BACKUP_TAR" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"

# Encrypt backup
echo "Encrypting backup..."
gpg -c --no-symkey-cache "$BACKUP_TAR"
BACKUP_TAR_GPG="$BACKUP_TAR.gpg"

# Verify backup
if [ -f "$BACKUP_TAR_GPG" ]; then
    echo "Backup completed: $BACKUP_TAR_GPG ($(du -sh "$BACKUP_TAR_GPG" | cut -f1))"
    notify-send "Backup Complete" "$BACKUP_TAR_GPG created"
    rm -rf "$BACKUP_DIR" "$BACKUP_TAR"
else
    echo "Error: Backup encryption failed."
    rm -rf "$BACKUP_DIR" "$BACKUP_TAR"
    exit 1
fi

# Clean up old backups (keep last 5)
echo "Cleaning up old backups..."
find "$HOME" -maxdepth 1 -name "backup_*.tar.gz.gpg" -type f -printf "%T@ %p\n" | sort -nr | tail -n +6 | cut -d' ' -f2- | xargs -r rm -v

exit 0
