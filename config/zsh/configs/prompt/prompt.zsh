#!/bin/zsh
# eval "$(starship init zsh)"

function middle_placer {
    local cmd="$1"
    local term_width=$(tmux display-message -p '#{pane_width}')  # Breite des tmux-Splits abrufen
    if [ -z "$term_width" ]; then
        term_width=$(tput cols)  # Terminalbreite abrufen
    fi

    local border_width=$((term_width - 4))  # Border-Breite berechnen
    local text_padding=$(( (border_width - ${#cmd}) / 2 + 1 ))  # Text-Padding berechnen

    local border_top='╭'$(printf '─%.0s' $(seq 1 $((border_width + 2))))'╮'
    local border_bottom='╰'$(printf '─%.0s' $(seq 1 $((border_width + 2))))'╯'
    local text_line='│%'$text_padding's%s%'$text_padding's│'

    printf '\e[2m'
    printf '%s\n' "$border_top"
    printf "$text_line\n" '' "$cmd"

    # Wenn der Text breiter als die Terminalbreite ist, wird er auf zwei Zeilen aufgeteilt
    if (( ${#cmd} > $border_width )); then
        local remainder="${cmd:$border_width}"
        local remainder_lines=$(( (${#remainder} + border_width - 1) / border_width )) # Anzahl der Zeilen für den Rest des Textes
        for ((i=0; i<remainder_lines; i++)); do
            printf "$text_line\n" '' "${remainder:($i * border_width)}"
        done
    fi
    printf '%s\n' "$border_bottom"
    printf '\e[0m'
}

function remind_alias {
    local cmd="$1"
    for alias_name in ${(k)aliases}; do
        if [[ ${aliases[$alias_name]} == "$cmd" ]]; then
            local message="Reminder: '$cmd' has an alias defined: alias $alias_name='${aliases[$alias_name]}'"
            middle_placer "$message"
            return
        fi
    done
}

PROMPT='%F{blue}$ '

precmd() {
    PROMPT_COMMAND_END_TIME=$SECONDS
    runtime=$((PROMPT_COMMAND_END_TIME - PROMPT_COMMAND_START_TIME))
    if [[ $runtime -gt 10 ]]; then
        RPROMPT="%F{red}${runtime}s%f"
    else
        RPROMPT=""
    fi
}

preexec() {
    PROMPT_COMMAND_START_TIME=$SECONDS
    remind_alias "$1"
}

autoload -Uz add-zsh-hook

add-zsh-hook -d precmd precmd
add-zsh-hook precmd precmd
