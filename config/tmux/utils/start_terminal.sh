#!/bin/bash
unset TMUX

[[ -f "$HOME/.local/state/quickshell/user/generated/terminal/sequences.txt" ]] && \
    cat "$HOME/.local/state/quickshell/user/generated/terminal/sequences.txt"

# tmux new-session -n shell "bash -c '$HOME/.scripts/colorful; exec zsh'"
tmux new-session -n shell "bash -c 'exec zsh'"
