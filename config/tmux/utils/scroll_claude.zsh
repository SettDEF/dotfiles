#!/usr/bin/env zsh
# Send PageUp / PageDown to any tmux pane running Claude Code.
# Wired to Shift+MouseWheel in tmux.conf.
#
# Usage: scroll_claude.zsh up|down [count]

set -u

dir="${1:-up}"
count="${2:-1}"

# Search every pane in every session for one running Claude. We check three
# tmux fields per pane so the detector survives:
#   - claude launched directly (`claude` in $PATH → pane_current_command)
#   - claude running as node/npm subprocess (title / start_command)
#   - a shell prompt containing "claude" (custom titles)
pane=$(tmux list-panes -a \
        -F '#{pane_id}|#{pane_current_command}|#{pane_title}|#{pane_start_command}' \
        2>/dev/null | \
    awk -F'|' '
        {
            cmd   = tolower($2)
            title = tolower($3)
            start = tolower($4)
            if (cmd ~ /claude/ || title ~ /claude/ || start ~ /claude/) {
                print $1; exit
            }
        }
    ')

if [[ -z "$pane" ]]; then
    exit 0
fi

case "$dir" in
    up)   key=PageUp ;;
    down) key=PageDown ;;
    *)    exit 0 ;;
esac

# Repeat `count` times so a single "wheel tick" moves proportionally.
for _ in $(seq 1 "$count"); do
    tmux send-keys -t "$pane" "$key"
done
