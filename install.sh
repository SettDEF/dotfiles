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
# @UID@ (a conf cannot read $XDG_RUNTIME_DIR, e.g. QUARRY_SOCK in hypr/custom/env.conf): this user's id
f="$HOME/.config/hypr/custom/env.conf"
[ -f "$f" ] && sed -i "s|@UID@|$(id -u)|g" "$f"
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
