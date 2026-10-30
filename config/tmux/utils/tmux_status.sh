#!/bin/bash

# Funktion zum Abrufen der aktuellen Sitzung
get_session_name() {
    tmux display-message -p '#S'
}

# Funktion zum Abrufen der aktuellen Sitzungsnummer
get_session_number() {
    local session_count=$(tmux list-sessions | wc -l)
    local current_session_index=$(tmux display-message -p "#{session_index}")
    echo "$((current_session_index + 1))/$session_count"
}

# Funktion zum Überprüfen, ob eine SSH-Verbindung besteht und die IP-Adresse abzurufen
get_ssh_ip() {
    local ssh_ip=$(ss -tn | grep -E 'ESTAB' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    if [ -n "$ssh_ip" ]; then
        echo "SSH: $ssh_ip"
    else
        echo ""
    fi
}

# Funktion zum Generieren der Statuszeile
generate_status_line() {
    local ssh_info=$(get_ssh_ip)
    local session_name=$(get_session_name)
    local session_number=$(get_session_number)

    # Erstellen der Statuszeile
    local status_line=""

    if [ -n "$ssh_info" ]; then
        status_line="#[fg=colour8,bg=black] #S #[fg=green,bg=black] #[fg=black,bg=green]󱫋 #{session_attached}#[fg=green,bg=black]"
    else
        status_line="#[fg=colour8,bg=black] #S #[fg=green,bg=black] #[fg=black,bg=green]󱫋 #{session_attached}#[fg=green,bg=black]"
    fi
    #[fg=colour8,bg=black] #S #[fg=green,bg=black] #[fg=black,bg=green]󱫋 #{session_attached}#[fg=green,bg=black]"
    echo "$status_line"
}

# Hauptausführung
while true; do
    status=$(generate_status_line)
    tmux set-option -g status-right "$status"
    sleep 5  # Aktualisiere alle 5 Sekunden
done
