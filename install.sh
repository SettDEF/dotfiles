#!/usr/bin/env bash
# install.sh: these configs into ~/.config and ~/.scripts (what was there is kept as NAME.bak-DATE), their packages and zplug
set -u
failed=()
cd "$(dirname "$0")"
stamp=$(date +%Y%m%d-%H%M%S)

# the packages they call; one the repos do not have is skipped, not fatal
pkgs=$(grep -v '^#' packages.txt | tr -s ' \n' '\n' | grep . | while read -r p; do pacman -Si "$p" >/dev/null 2>&1 && echo "$p"; done)
[ -n "$pkgs" ] && sudo pacman -S --needed --noconfirm $pkgs </dev/tty || echo "some packages did not install"

# zplug, which ~/.config/zsh/.zshrc loads from ~/.zplug
[ -d "$HOME/.zplug" ] || git clone -q --depth 1 https://github.com/zplug/zplug "$HOME/.zplug" || echo "zplug: could not clone"
command -v zsh >/dev/null && zsh -c 'source ~/.zplug/init.zsh; zplug "zsh-users/zsh-syntax-highlighting"; zplug "zsh-users/zsh-autosuggestions"; zplug check || zplug install' </dev/null >/dev/null 2>&1 || echo "zplug: plugins not installed (zplug install)"

put() {   # put SRC DEST: one that fails is reported, the rest still goes in
    if [ -e "$2" ] && ! diff -rq "$1" "$2" >/dev/null 2>&1; then
        # the copy is only removed once it is kept: a failed mv must not lose it
        mv "$2" "$2.bak-$stamp" || { echo "could not keep $2, left as it was" >&2; failed+=("$2"); return; }
        echo "kept $2 as $2.bak-$stamp"
    fi
    mkdir -p "$(dirname "$2")" && rm -rf "$2" && cp -r "$1" "$2" || { echo "could not install $2" >&2; failed+=("$2"); }
}
for d in config/*; do put "$d" "$HOME/.config/${d#config/}"; done
put home/.scripts "$HOME/.scripts"
# paths to the other laptop's home (/home/caesar), e.g. in the shell's settings file: pointed at this home
if [ "$HOME" != /home/caesar ]; then
    # only what this repo put there, and /home/caesar as a whole name (not /home/caesarium)
    targets=("$HOME/.scripts"); for d in config/*; do targets+=("$HOME/.config/${d#config/}"); done
    grep -rIlE '/home/caesar\b' "${targets[@]}" 2>/dev/null | while IFS= read -r f; do sed -i -E "s|/home/caesar\b|$HOME|g" "$f"; done
fi
# ── icons and cursor: the ones the GTK settings name, installed, and set the same everywhere ──
# (they named Reversal and Oxygen_White, but nothing installed either: GTK fell back to blank
# icons, and the compositor, X11, GTK and Qt each drew their own cursor)
gtk3="$HOME/.config/gtk-3.0/settings.ini"
ini() { sed -n "s/^$1=//p" "$gtk3" 2>/dev/null | head -1; }
icons=$(ini gtk-icon-theme-name); cursor=$(ini gtk-cursor-theme-name)
# 24 suits most screens; the Z13's was 38 (CURSOR_SIZE=38 ./install.sh)
csize=${CURSOR_SIZE:-24}
theme_dir() { for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do [ -d "$d/$1" ] && { echo "$d/$1"; return 0; }; done; return 1; }
# Reversal is not in the repos: its own installer, from GitHub, into ~/.local/share/icons (no sudo)
case "$icons" in Reversal|Reversal-dark)
    if ! theme_dir "$icons" >/dev/null; then
        tmp=$(mktemp -d)
        if git clone -q --depth 1 https://github.com/yeyushengfan258/Reversal-icon-theme "$tmp/reversal" \
           && (cd "$tmp/reversal" && ./install.sh -d "$HOME/.local/share/icons" -t default >/dev/null 2>&1); then
            echo "icons: Reversal installed"
        else
            echo "icons: Reversal could not be fetched"
        fi
        rm -rf "$tmp"
    fi ;;
esac
# still missing: Papirus (packages.txt) rather than blank icons; Adwaita rather than mixed cursors
# (the first of these that is installed: a package that failed above must not mean blank icons)
if [ -z "$icons" ] || ! theme_dir "$icons" >/dev/null; then
    for t in Papirus-Dark breeze-dark Adwaita; do theme_dir "$t" >/dev/null && { icons=$t; break; }; done
    echo "icons: using $icons"
fi
if [ -z "$cursor" ] || ! [ -d "$(theme_dir "$cursor")/cursors" ]; then
    for t in Adwaita breeze_cursors; do [ -d "$(theme_dir "$t")/cursors" ] && { cursor=$t; break; }; done
    echo "cursor: using $cursor"
fi
for f in "$gtk3" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] && sed -i -E "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$icons|; s|^gtk-cursor-theme-name=.*|gtk-cursor-theme-name=$cursor|; s|^gtk-cursor-theme-size=.*|gtk-cursor-theme-size=$csize|" "$f"
done
# the compositor (Hyprland, loom) and what it starts
for f in "$HOME/.config/hypr/custom/env.conf" "$HOME/.config/hypr/lua/custom/env.lua"; do
    [ -f "$f" ] && sed -i "s|@CURSOR@|$cursor|g; s|@CURSOR_SIZE@|$csize|g" "$f"
done
# X11 programs and anything without a setting of its own
mkdir -p "$HOME/.icons/default" && printf '[Icon Theme]\nInherits=%s\n' "$cursor" > "$HOME/.icons/default/index.theme"
# GTK 4, libadwaita, Electron and the portals read gsettings; Qt through the KDE platform theme reads KDE's files
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface icon-theme "$icons" 2>/dev/null
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null
    gsettings set org.gnome.desktop.interface cursor-size "$csize" 2>/dev/null
fi
if command -v kwriteconfig6 >/dev/null; then
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icons"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$cursor"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$csize"
fi
echo "icons: $icons, cursor: $cursor $csize"

# the shell's wallpaper: one that exists here (else a black desktop): your first picture, or ii's own
cfg="$HOME/.config/illogical-impulse/config.json"
if [ -f "$cfg" ] && command -v jq >/dev/null; then
    wp=$(jq -r '.background.wallpaperPath // ""' "$cfg")
    if [ -z "$wp" ] || [ ! -f "$wp" ]; then
        wp=$(find "$HOME/Pictures/Wallpapers" "$HOME/Pictures" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -1)
        [ -n "$wp" ] || wp="$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
        jq --arg w "$wp" '.background.wallpaperPath = $w | .background.wallpaperSourcePath = "" | .background.thumbnailPath = "" | .background.crop.perFile = {}' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
        echo "wallpaper: $wp"
    fi
fi
# ~/.zshrc loads the real one in ~/.config/zsh
if ! grep -qs 'config/zsh/.zshrc' "$HOME/.zshrc"; then
    [ -e "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak-$stamp"
    printf 'source $HOME/.config/zsh/.zshrc\n[ -f "$HOME/.secure/load-keys.sh" ] && . "$HOME/.secure/load-keys.sh"\n' > "$HOME/.zshrc"
fi
# what Hyprland and zsh need, checked
for f in "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/zsh/.zshrc"; do [ -f "$f" ] || failed+=("$f (missing)"); done
if [ ${#failed[@]} -gt 0 ]; then printf 'NOT installed: %s\n' "${failed[@]}" >&2; exit 1; fi
echo "dotfiles installed; open a new terminal"
