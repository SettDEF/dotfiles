#!/usr/bin/env bash
# install.sh: these configs into ~/.config and ~/.scripts; what was there is kept as NAME.bak-DATE
set -eu
cd "$(dirname "$0")"
stamp=$(date +%Y%m%d-%H%M%S)
put() {   # put SRC DEST
    if [ -e "$2" ] && ! diff -rq "$1" "$2" >/dev/null 2>&1; then mv "$2" "$2.bak-$stamp"; echo "kept $2 as $2.bak-$stamp"; fi
    mkdir -p "$(dirname "$2")"; cp -a "$1" "$2"
}
for d in config/*; do put "$d" "$HOME/.config/${d#config/}"; done
put home/.scripts "$HOME/.scripts"
# ~/.zshrc loads the real one in ~/.config/zsh
if ! grep -qs 'config/zsh/.zshrc' "$HOME/.zshrc"; then
    [ -e "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak-$stamp"
    printf 'source $HOME/.config/zsh/.zshrc\n[ -f "$HOME/.secure/load-keys.sh" ] && . "$HOME/.secure/load-keys.sh"\n' > "$HOME/.zshrc"
fi
echo "dotfiles installed; open a new terminal"
