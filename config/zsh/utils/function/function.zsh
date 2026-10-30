# funcitons 
_auto_fix_zsh_history() {
    local hist_file="${HISTFILE:-$HOME/.zsh_history}"
    [[ -f "$hist_file" ]] || return 0

    # Check if fc -R fails due to null byte corruption or bad formatting
    if ! fc -R "$hist_file" 2>/dev/null; then
        # Strip null bytes in-place losslessly
        tr -d '\0' < "$hist_file" > "${hist_file}.tmp" \
            && mv "${hist_file}.tmp" "$hist_file"
        
        # Reload repaired history
        fc -R "$hist_file" 2>/dev/null
    fi
}


