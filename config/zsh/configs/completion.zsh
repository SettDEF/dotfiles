fpath=(~/.zsh/completion $fpath)

autoload -Uz compinit
# the full check (compaudit, a fresh dump) once a day; otherwise the saved dump is read as it is
() {
  setopt localoptions extendedglob
  local dump=${ZDOTDIR:-$HOME}/.zcompdump
  if [[ -n $dump(#qN.mh+24) || ! -s $dump ]]; then compinit; else compinit -C; fi
}

# what completers work out once (package lists, man pages …) is kept on disk, not asked again
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"

## case-insensitive (all), partial-word and then substring completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' \
    'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
