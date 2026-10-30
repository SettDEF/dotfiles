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
    if [ -e "$2" ] && ! diff -rq "$1" "$2" >/dev/null 2>&1; then mv "$2" "$2.bak-$stamp" && echo "kept $2 as $2.bak-$stamp"; fi
    mkdir -p "$(dirname "$2")" && rm -rf "$2" && cp -r "$1" "$2" || { echo "could not install $2" >&2; failed+=("$2"); }
}
for d in config/*; do put "$d" "$HOME/.config/${d#config/}"; done
put home/.scripts "$HOME/.scripts"
# paths to the other laptop's home (/home/caesar), e.g. in the shell's settings file: pointed at this home
if [ "$HOME" != /home/caesar ]; then
    grep -rIl /home/caesar "$HOME/.config" "$HOME/.scripts" 2>/dev/null | while IFS= read -r f; do sed -i "s|/home/caesar|$HOME|g" "$f"; done
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
