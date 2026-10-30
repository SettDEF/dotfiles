# Enter while zash-popup's list is open: the list closes and the line is drawn again first, then the line runs.
# Without it, in a terminal that shows the plain-text list (zett's panel), the list was cleared after the line
# was accepted and wrote over the command and its output: `ls` + Enter seemed to do nothing.
(( $+functions[_zash_close] )) || return
_zash_accept() { if (( _zash_open )); then _zash_close; zle -R; fi; zle .accept-line }
zle -N _zash_accept
_zash_accept_install() {
  add-zsh-hook -d precmd _zash_accept_install
  local m; for m in viins emacs; do bindkey -M $m '^M' _zash_accept; bindkey -M $m '^J' _zash_accept; done
}
add-zsh-hook precmd _zash_accept_install
