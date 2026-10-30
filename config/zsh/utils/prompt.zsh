# ── Prompt enhancements: project detection, runtime pill, richer git ──
# Sourced from ~/.config/zsh/.zshrc AFTER update_prompt_data is defined.

# ── Icon set (override any of these to customize) ──────────────────────────
: ${PROMPT_ICON_CLEAN:=""}                                # nf-fa-check
: ${PROMPT_ICON_DIRTY:="●"}                                 # solid dot
: ${PROMPT_ICON_AHEAD:="⇡"}                                 # arrow up
: ${PROMPT_ICON_BEHIND:="⇣"}                                # arrow down
: ${PROMPT_ICON_STASH:=""}                                 # nf-md-archive
: ${PROMPT_ICON_PROJECT:="󰺾"}                               # nf-md-briefcase_variant
: ${PROMPT_ICON_BRANCH:=""}                                # nf-dev-git_branch

update_prompt_data() {
    # Tor
    if [ -n "$TOR_ACTIVE" ]; then
        prompt_tor="%F{red}%K{red}%F{black}󰒍 TOR%k%F{red}%f "
    else
        prompt_tor=""
    fi

    # Session
    prompt_session="%F{blue}%K{blue}%F{black}%n@%m%k%F{blue}%f "

    # Project
    prompt_project=""
    local _project_name _project_rel
    if _detect_project; then
        prompt_project="%F{cyan}%K{cyan}%F{black}${PROMPT_ICON_PROJECT} ${_project_name}%k%F{cyan}%f "
    fi

    # Directory
    local icon="$ICON_DIR"
    if [[ "$PWD" == "$HOME" ]]; then
        icon="$ICON_HOME"
    elif git rev-parse --is-inside-work-tree &>/dev/null; then
        icon="$ICON_GIT"
    elif [[ -f "package.json" ]]; then
        icon="$ICON_NODE"
    elif [[ -f "Cargo.toml" ]]; then
        icon=""
    elif [[ -f "go.mod" ]]; then
        icon=""
    elif [[ -f "requirements.txt" || -f "pyproject.toml" || -d ".venv" || -d "venv" ]]; then
        icon="$ICON_PYTHON"
    fi
    local dir_label
    if [[ -n "$_project_name" ]]; then
        dir_label="$_project_rel"
    else
        dir_label="%2~"
    fi
    if [[ -n "$dir_label" ]]; then
        prompt_dir="%F{magenta}%K{magenta}%F{black}${icon} ${dir_label}%k%F{magenta}%f"
    else
        prompt_dir=""
    fi

    # Git
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local branch status_color status_icon counts ahead behind stashes
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            status_icon=" ${PROMPT_ICON_DIRTY}"; status_color="yellow"
        else
            status_icon=" ${PROMPT_ICON_CLEAN}"; status_color="green"
        fi
        counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
        if [[ -n "$counts" ]]; then
            behind=${counts%%[[:space:]]*}
            ahead=${counts##*[[:space:]]}
            (( ahead  > 0 )) && status_icon+=" ${PROMPT_ICON_AHEAD}${ahead}"
            (( behind > 0 )) && status_icon+=" ${PROMPT_ICON_BEHIND}${behind}"
        fi
        stashes=$(git stash list 2>/dev/null | wc -l)
        (( stashes > 0 )) && status_icon+=" ${PROMPT_ICON_STASH}${stashes}"
        prompt_git=" %F{${status_color}}%K{${status_color}}%F{black} ${PROMPT_ICON_BRANCH} ${branch}${status_icon}%k%F{${status_color}}%f"
    else
        prompt_git=""
    fi

    # Runtime
    prompt_runtime=""
    if [[ -f "package.json" ]]; then
        local nv=""
        command -v node >/dev/null 2>&1 && nv=" $(node -v 2>/dev/null | tr -d 'v\n')"
        prompt_runtime=" %F{green}%K{green}%F{black}${nv}%k%F{green}%f"
    elif [[ -f "Cargo.toml" ]]; then
        local rv=""
        command -v rustc >/dev/null 2>&1 && rv=" $(rustc --version 2>/dev/null | awk '{print $2}')"
        prompt_runtime=" %F{red}%K{red}%F{black}${rv}%k%F{red}%f"
    elif [[ -f "go.mod" ]]; then
        local gv=""
        command -v go >/dev/null 2>&1 && gv=" $(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')"
        prompt_runtime=" %F{cyan}%K{cyan}%F{black}${gv}%k%F{cyan}%f"
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        prompt_runtime=" %F{yellow}%K{yellow}%F{black} ${VIRTUAL_ENV:t}%k%F{yellow}%f"
    elif [[ -f "pyproject.toml" || -f "requirements.txt" ]]; then
        local pv=""
        command -v python3 >/dev/null 2>&1 && pv=" $(python3 -V 2>/dev/null | awk '{print $2}')"
        prompt_runtime=" %F{yellow}%K{yellow}%F{black}${pv}%k%F{yellow}%f"
    fi

    # Timer
    if [[ -n "$_cmd_start" ]]; then
        local elapsed=$(( EPOCHREALTIME - _cmd_start ))
        unset _cmd_start
        local human
        if (( elapsed < 1 )); then
            human="$(printf '%.0fms' $(( elapsed * 1000 )))"
        elif (( elapsed < 60 )); then
            human="$(printf '%.2fs' $elapsed)"
        else
            local isecs=$(printf '%.0f' $elapsed)
            human="$(( isecs / 60 ))m$(( isecs % 60 ))s"
        fi
        prompt_timer="%F{cyan} ${human}%f"
    else
        prompt_timer=""
    fi

    PROMPT="${prompt_tor}${prompt_session}${prompt_project}${prompt_dir}${prompt_git}${prompt_runtime}
%(?.%F{\${__pmode_accent}}.%F{red})❯%f "
    _refresh_rprompt
}
