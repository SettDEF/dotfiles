#         _              
# _______| |__  _ __ ___ 
#|_  / __| '_ \| '__/ __|
# / /\__ \ | | | | | (__ 
#/___|___/_| |_|_|  \___|
# gotbletu (@gmail|twitter|youtube|github|lbry)
#-------- Prompt/settings {{{
#------------------------------------------------------
# https://wiki.archlinux.org/index.php/Zsh#Prompts
autoload -U promptinit && promptinit
prompt fade magenta   # set prompt theme (for listing: $ prompt -p)

# Enable profiling (uncomment to debug loading times)
# zmodload zsh/zprof

# Compile zshrc if changed
if [ ~/.zshrc -nt ~/.zshrc.zwc ]; then
    zcompile ~/.zshrc
fi

# Avoid unnecessary stat calls
skip_global_compinit=1

# Load binary modules first for better performance
zmodload zsh/complist
zmodload zsh/complete

# }}}
#-------- Source External Files {{{
#------------------------------------------------------
#
# ~/.config/zsh/configs — sourced FIRST, deliberately.
#
# Twelve files in here had never run: nothing sourced the directory, so 157
# aliases and every keybinding in it were dead code. `general.zsh` also had
# `--export EDITOR="nvim"` on line 3, which is likely why: one error early in
# an alphabetical loop takes everything after it.
#
# First rather than last, because ~/.config/function/functionrc redefines four
# of these aliases (df, du, free, c) with better versions, and utils/ later
# still. Load order is the precedence: oldest definitions first, newest last.
#
if [ -d "$HOME/.config/zsh/configs" ]; then
  for f in "$HOME"/.config/zsh/configs/*.zsh(N); do source "$f"; done
  unset f
fi

# source all files in function directory
if [ -d "$HOME/.config/function" ]; then
  for f in "$HOME"/.config/function/*
    do source "$f"
  done
fi

[[ -f ~/.config/zsh/utils/function/function.zsh ]] && source ~/.config/zsh/utils/function/function.zsh

# for file in * ; do
#   if [ -f "$file" ] ; then
#     . "$file"
#   fi
# done

#}}}
# plugins {{{ 
source ~/.zplug/init.zsh
# Install some badass plugins with Zplug
# These plugins are like your digital arsenal
zplug "zsh-users/zsh-syntax-highlighting", defer:3
zplug "zsh-users/zsh-autosuggestions", defer:1 #, use:autosuggestions
# zplug "zsh-users/zsh-completions", defer:2
# zplug "mollifier/cd-gitroot"
# zplug "zsh-users/zsh-history-substring-search"
# zplug "$HOME/.config/zsh/git.zsh", from:local, use:"*"

# Load and manage plugins with Zplug
zplug load
# zash-popup: completions in a popup while typing, Tab cycles (works in any terminal)
[[ -f ~/.local/share/zash/shell/zsh/zash-popup.plugin.zsh ]] && source ~/.local/share/zash/shell/zsh/zash-popup.plugin.zsh

# }}}
# ------ Theme colors (tinct) {{{
#------------------------------------------------------
# Pulls the live Material You palette (written by the wallpaper pipeline at
# ~/.local/state/quickshell/user/generated/zsh_colors.zsh). Only used to tint
# the vi-mode arrow on line 2 — INSERT = primary, NORMAL = tertiary.
__zsh_setup_mode_colors() {
    local cfile="$HOME/.local/state/quickshell/user/generated/zsh_colors.zsh"
    [[ -r "$cfile" ]] && source "$cfile"
    : ${ZSH_THEME_PRIMARY:=#ddc4e9}
    : ${ZSH_THEME_TERTIARY:=#cfe8c3}
    : ${ZSH_THEME_ERROR:=#ffb4ab}

    typeset -g ZSH_MODE_INSERT_ACCENT="$ZSH_THEME_PRIMARY"
    typeset -g ZSH_MODE_NORMAL_ACCENT="$ZSH_THEME_TERTIARY"
    # Arrow colour for the current vi mode; swapped on every mode change.
    typeset -g __pmode_accent="$ZSH_MODE_INSERT_ACCENT"
}
__zsh_setup_mode_colors
# A wallpaper change rewrites the file: running shells take it at their next prompt (zstat is a
# builtin, so the check costs no process).
typeset -g __zsh_colors_mtime=0
__zsh_colors_refresh() {
    local cfile="$HOME/.local/state/quickshell/user/generated/zsh_colors.zsh"
    local -a m
    zmodload -F zsh/stat b:zstat 2>/dev/null
    zstat -A m +mtime -- "$cfile" 2>/dev/null || return
    (( m[1] == __zsh_colors_mtime )) && return
    (( __zsh_colors_mtime )) && unset ZSH_THEME_PRIMARY ZSH_THEME_TERTIARY ZSH_THEME_ERROR
    __zsh_colors_mtime=$m[1]
    __zsh_setup_mode_colors
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd __zsh_colors_refresh
# }}}
# ------ Prompt {{{
# Directories to treat as "project roots" — any direct subdirectory is a
# project. When cwd is inside one, the prompt shows a project pill + a path
# relative to the project instead of the full path.
typeset -ga PROMPT_PROJECT_ROOTS=(
    "/mnt/storage/dev/projects"
    "$HOME/workspace"
)

# Exclude some paths for the hooks
local excluded_dirs=(
"~/.config"
)

# Nerd Font Icons
local ICON_HOME=""
local ICON_GIT=""
local ICON_DIR=""
local ICON_PYTHON=""
local ICON_NODE=""

# ── Dynamic Prompt Variables ──────────────────────────────────────────────────
local prompt_tor=""
local prompt_session=""
local prompt_project=""
local prompt_dir=""
local prompt_git=""
local prompt_runtime=""
local prompt_timer=""
local _vim_rprompt=""

# ── Project detection ─────────────────────────────────────────────────────────
# Walks up from $PWD looking for a parent that IS one of PROMPT_PROJECT_ROOTS.
# Returns the project name (first subdirectory under the root) and the
# relative path inside that project via _project_name / _project_rel.
_detect_project() {
    _project_name=""
    _project_rel=""
    local pwd_abs="${PWD:A}"
    for root in $PROMPT_PROJECT_ROOTS; do
        local root_abs="${root:A}"
        [[ -z "$root_abs" || ! -d "$root_abs" ]] && continue
        if [[ "$pwd_abs" == "$root_abs"/* ]]; then
            local rest="${pwd_abs#$root_abs/}"
            _project_name="${rest%%/*}"
            _project_rel="${rest#$_project_name}"
            _project_rel="${_project_rel#/}"
            return 0
        fi
    done
    return 1
}

# Record command start time (for the execution-time segment)
zmodload zsh/datetime 2>/dev/null
_prompt_timer_preexec() { _cmd_start=$EPOCHREALTIME }

# Combine timer + vim-mode into the right prompt (called from both hooks)
_refresh_rprompt() {
    RPS1="${prompt_timer}${prompt_timer:+ }${_vim_rprompt}"
    RPS2="$RPS1"
}

# Precmd Hook to update dynamic prompt components
update_prompt_data() {
    # 1. Tor Status
    if [ -n "$TOR_ACTIVE" ]; then
        prompt_tor="%F{red}%K{red}%F{black}󰒍 TOR%F{red}%k%f "
    else
        prompt_tor=""
    fi

    # 2. Session (User @ Host)
    prompt_session="%F{blue}%K{blue}%F{black}%n@%m%F{blue}%k%f "

    # 3. Directory Icon and Shortened Path
    local icon="$ICON_DIR"
    if [[ "$PWD" == "$HOME" ]]; then
        icon="$ICON_HOME"
    elif git rev-parse --is-inside-work-tree &>/dev/null; then
        icon="$ICON_GIT"
    elif [[ -f "package.json" ]]; then
        icon="$ICON_NODE"
    elif [[ -f "requirements.txt" || -f "pyproject.toml" || -d ".venv" || -d "venv" ]]; then
        icon="$ICON_PYTHON"
    fi
    prompt_dir="%F{magenta}%K{magenta}%F{black}${icon} %2~%F{magenta}%k%f"

    # 4. Git branch & status
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        local status_icon=""
        local status_color="green" # Clean by default

        # Check staged/unstaged changes
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            status_icon=" ✗"
            status_color="yellow" # Dirty
        else
            status_icon=" ✔"
        fi

        prompt_git=" %F{${status_color}}%K{${status_color}}%F{black} ${branch}${status_icon}%F{${status_color}}%k%f"
    else
        prompt_git=""
    fi

    # 5. Command execution time (only shown when a command actually ran)
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

    # Assemble line 1 and line 2
    PROMPT="${prompt_tor}${prompt_session}${prompt_dir}${prompt_git}
%(?.%F{\${__pmode_accent}}.%F{red})❯%f "

    # Right prompt = command timer + vim-mode indicator (see zle-keymap-select)
    _refresh_rprompt
}

autoload -U add-zsh-hook
add-zsh-hook preexec _prompt_timer_preexec
add-zsh-hook precmd update_prompt_data
setopt PROMPT_SUBST

# Source everything under ~/.config/zsh/utils/*.zsh. Currently overrides
# update_prompt_data with the enhanced version (project detection,
# runtime pill, richer git).
for _u in "$HOME"/.config/zsh/utils/*.zsh(N); do source "$_u"; done
unset _u
# }}}
#-------- Vim Mode {{{
#------------------------------------------------------
# enable vim mode on commmand line
bindkey -v

# edit command with editor
# http://stackoverflow.com/a/903973
# usage: type someshit then hit Esc+v
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# no delay entering normal mode
# https://github.com/pda/dotzsh/blob/master/keyboard.zsh#L10
# 100ms for key sequences. 10ms was too tight: a bracketed-paste marker
# (ESC [ 2 0 0 ~) split by tmux/WezTerm made zsh drop to NORMAL mode and run the
# pasted letters as vi commands (the "g" in storage/pkg disappeared).
KEYTIMEOUT=10

# show vim status
# http://zshwiki.org/home/examples/zlewidgets
autoload -Uz vcs_info
function zle-keymap-select() {
  if [[ ${KEYMAP} == vicmd ]]; then
    echo -ne '\e[1q' # Block cursor for Normal mode
  else
    echo -ne '\e[5q' # Beam cursor for Insert mode
  fi
  local mode
  local color
  case $KEYMAP in
    vicmd) mode='[NORMAL]'; __pmode_accent="$ZSH_MODE_NORMAL_ACCENT"; color='%F{blue}';;
    main|viins) mode='[INSERT]'; __pmode_accent="$ZSH_MODE_INSERT_ACCENT"; color='%F{green}';;
    *) mode='[UNKNOWN]'; color='%F{cyan}';;
  esac
  _vim_rprompt="${color}${mode}%f"
  _refresh_rprompt
  zle reset-prompt
}
zle -N zle-keymap-select

function zle-line-init() {
  zle -K viins
  __pmode_accent="$ZSH_MODE_INSERT_ACCENT"
  echo -ne '\e[5q' # Reset to beam cursor on command initialization
}
zle -N zle-line-init

# add missing vim hotkeys
# fixes backspace deletion issues
# http://zshwiki.org/home/zle/vi-mode
bindkey -a u undo
# bindkey -a '^R' redo	# conflicts with history search hotkey
bindkey -a '^T' redo
bindkey '^?' backward-delete-char	#backspace

# history search in vim mode
# http://zshwiki.org./home/zle/bindkeys#why_isn_t_control-r_working_anymore
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M vicmd '^r' history-incremental-search-backward

# use cursor blinker color as indicator of vi mode
# http://andreasbwagner.tumblr.com/post/804629866/zsh-cursor-color-vi-mode
# http://reza.jelveh.me/2011/09/18/zsh-tmux-vi-mode-cursor

# bug; 112 ascii randomly showing up

# zle-keymap-select () {
#  if [ $KEYMAP = vicmd ]; then
#    if [[ $TMUX = '' ]]; then
#      echo -ne "\033]12;Red\007"
#    else
#      printf '\033Ptmux;\033\033]12;red\007\033\\'
#    fi
#  else
#    if [[ $TMUX = '' ]]; then
#      echo -ne "\033]12;Grey\007"
#    else
#      printf '\033Ptmux;\033\033]12;grey\007\033\\'
#    fi
#  fi
#}
#zle-line-init () {
#  zle -K viins
#  echo -ne "\033]12;Grey\007"
#}
#zle -N zle-keymap-select
#zle -N zle-line-init

# }}}
#-------- Autocomplete {{{
#------------------------------------------------------
# http://www.refining-linux.org/archives/40/ZSH-Gem-5-Menu-selection/
# https://github.com/robbyrussell/oh-my-zsh/blob/master/lib/completion.zsh


# compinit runs once, in configs/completion.zsh (with the cache and the daily check)
zstyle ':completion:*' menu select      # to activate the menu, press tab twice

# do not autoselect the first completion entry
unsetopt menu_complete

# autocompletion CLI switches for aliases
setopt completealiases

zstyle ':completion:*' list-colors ''   # show colors on menu completion

# http://unix.stackexchange.com/a/297000
# tab completion from both ends
setopt complete_in_word
setopt glob_complete                    # wildcard completion eg. *-tar

# setopt auto_menu         # show completion menu on succesive tab press
setopt always_to_end

# show dots if tab compeletion is taking long to load
expand-or-complete-with-dots() {
  echo -n "\e[31m......\e[0m"
  zle expand-or-complete
  zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

# autocomplete case-insensitive (all),partial-word and then substring
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# better completion for killall
zstyle ':completion:*:killall:*' command 'ps -u $USER -o cmd'

# when new programs is installed, auto update autocomplete without reloading shell
zstyle ':completion:*' rehash true

#}}}
#-------- Suffix Alias {{{
#------------------------------------------------------
# open file with default program base on extension
# Ex: 'alias -s avi=mplayer' makes 'file.avi' execute 'mplayer file.avi'
background() { nohup "$@" >/dev/null 2>&1& }   # background a process w/o error msg filling screen

alias -s {avi,flv,mkv,mp4,mpeg,mpg,ogv,wmv}=$PLAYER
alias -s {flac,mp3,ogg,wav}=$MUSICER
alias -s {gif,GIF,jpeg,JPEG,jpg,JPG,png,PNG}="background $IMAGEVIEWER"
alias -s {djvu,pdf,ps}="background $READER"
alias -s txt=$EDITOR
alias -s epub="background $EBOOKER"
alias -s {cbr,cbz}="background $COMICER"
# might conflict with emacs org mode
alias -s {at,ch,com,de,net,org}="background $BROWSER"

# archive extractor
alias -s ace="unace l"
alias -s rar="unrar l"
alias -s {tar,bz2,gz,xz}="tar tvf"	#tar.bz2,tar.gz,tar.xz
alias -s zip="unzip -l"

#}}}
#-------- Expanding Alias {{{
#------------------------------------------------------
# Expanding aliases in zsh
# source: http://wiki.math.cmu.edu/iki/wiki/tips/20140625-zsh-expand-alias.html
# typeset -a ealiases
# ealiases=()
# ealias() {
#   alias $1
#   ealiases+=(${1%%\=*})
# }
# expand-ealias() {
#   if [[ $LBUFFER =~ "(^|[;|&])\s*(${(j:|:)ealiases})\$" ]]; then
#     zle _expand_alias
#     zle expand-word
#   fi
#   zle magic-space
# }
# zle -N expand-ealias
# # bindkey -M viins ' '  expand-ealias   # space to expand
# bindkey -M viins '^[[Z' expand-ealias   # shift-tab to expand
# bindkey -M viins '^ '   magic-space     # control-space to bypass completion
# bindkey -M isearch " "  magic-space     # normal space during searches
#
# # Expandable Alias
# ealias TSP='TS_SOCKET=/tmp/ranger tsp'




# }}}
#-------- Global Alias {{{
#------------------------------------------------------
# Automatically Expanding Global Aliases (Space key to expand)
# references: http://blog.patshead.com/2012/11/automatically-expaning-zsh-global-aliases---simplified.html
globalias() {
  if [[ $LBUFFER =~ '[A-Z0-9]+$' ]]; then
    zle _expand_alias
    zle expand-word
  fi
  zle self-insert
}
zle -N globalias
bindkey " " globalias                 # space key to expand globalalias
# bindkey "^ " magic-space            # control-space to bypass completion
bindkey "^[[Z" magic-space            # shift-tab to bypass completion
bindkey -M isearch " " magic-space    # normal space during searches


alias -g BELL='&& sleep 2 && echo -e "\a"'

# http://www.zzapper.co.uk/zshtips.html
alias -g ND='*(/om[1])' 	      # newest directory
alias -g NF='*(.om[1])' 	      # newest file
# alias -g V='| vim -R -'
alias -g V='| vless'
alias -g L='| less -N'
alias -g W='| w3m'
alias -g G='| grep -i '
alias -g AWK="awk -F';' '/cheat/ {print $1}'"
alias -g CUT="cut -d' ' -f2-"
alias -g SED="sed 's@@@g'"
alias -g WC='| wc -l'
alias -g WR='| while read line ; do echo "$line" ; done'
alias -g WRA='| while read -r line ; do aria2c "$line" ; done'
alias -g WRW='| while read -r line ; do aria2c "$line" ; done'



#alias -g NE='2>|/dev/null'
alias -g NO='&>|/dev/null'
alias -g PP='2>&1 | $PAGER'
alias -g HH='| head'
alias -g TT='| tail'
alias -g LL="2>&1 | less"
alias -g CA="2>&1 | cat -A"
alias -g NE="2> /dev/null"
alias -g NUL="> /dev/null 2>&1"
# some global aliases for redirection
alias -g NN="&>/dev/null"
alias -g 1N="1>/dev/null"
alias -g 2N="2>/dev/null"
alias -g DN="/dev/null"
alias -g PI="|"
# Paging with less / head / tail
alias -g LS='| less -S'
alias -g EL='|& less'
alias -g ELS='|& less -S'
alias -g TRIM='| cut -c 1-$COLUMNS'
alias -g HL='| head -n $(( +LINES ? LINES - 4 : 20 ))'
alias -g EH='|& head'
alias -g EHL='|& head -n $(( +LINES ? LINES - 4 : 20 ))'
alias -g TL='| tail -n $(( +LINES ? LINES - 4 : 20 ))'
alias -g ET='|& tail'
alias -g ETL='|& tail -n $(( +LINES ? LINES - 4 : 20 ))'
# Sorting / counting
alias -g CC='| wc -l'
alias -g SS='| sort'
alias -g Su='| sort -u'
alias -g Sn='| sort -n'
alias -g Snr='| sort -nr'

#}}}

#-------- Keybinding {{{
#------------------------------------------------------
# manpages for keybindings: $man zshzle

# partial history search using up and down arrow keys
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Bang! Previous Command Hotkeys
# print previous command but only the first nth arguments
# Alt+1, Alt+2 ...etc
# http://www.softpanorama.org/Scripting/Shellorama/bash_command_history_reuse.shtml#Bang_commands
bindkey -s '\e1' "!:0 \t"        # last command
bindkey -s '\e2' "!:0-1 \t"      # last command + 1st argument
bindkey -s '\e3' "!:0-2 \t"      # last command + 1st-2nd argument
bindkey -s '\e4' "!:0-3 \t"      # last command + 1st-3rd argument
bindkey -s '\e5' "!:0-4 \t"      # last command + 1st-4th argument
bindkey -s '\e`' "!:0- \t"       # all but the last argument
bindkey -s '\e9' "!:0 !:2* \t"   # all but the 1st argument (aka 2nd word)


# history search fzf
# references: https://github.com/junegunn/fzf/wiki/examples#command-history
# fzf-history-zsh() { print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac --height 10% | sed 's/ *[0-9]* *//') ;}
# bindkey -s '^R' "fzf-history-zsh\n"


# history search fzf widget
# references: https://github.com/junegunn/fzf/wiki/examples#locate
fzf-history-widget() {
  # Reads the `history` array directly: `fc -l` prefixes rows with numbers and a
  # `*` marker (which ended up in the buffer) and splits multi-line commands.
  setopt local_options no_aliases
  local -a keys entries
  local k selected
  keys=(${(Onk)history})                      # newest first
  for k in $keys; do entries+=("$history[$k]"); done
  entries=("${(@u)entries}")                  # drop duplicates, keep newest
  selected=$(print -rNC1 -- "${entries[@]}" | fzf --read0 --exact \
      --query="$LBUFFER" \
      --scheme=history \
      --height 40% \
      --layout=reverse \
      --border=rounded \
      --info=inline \
      --prompt="History > ") || { zle redisplay; return }
  LBUFFER=$selected
  zle redisplay
}
zle -N fzf-history-widget
bindkey -M viins '^R' fzf-history-widget
bindkey -M vicmd '^R' fzf-history-widget


#}}}
#-------- ZMV {{{
#------------------------------------------------------
# http://onethingwell.org/post/24608988305/zmv
autoload zmv

# }}}

#-------- Fuzzy Finder {{{
#------------------------------------------------------
#

# function bind to a hotkey
fzf_history() { zle -I; eval $(history | fzf +s | sed 's/ *[0-9]* *//') ; }; zle -N fzf_history; bindkey '^F' fzf_history

fzf_killps() { zle -I; ps -ef | sed 1d | fzf -m | awk '{print $2}' | xargs kill -${1:-9} ; }; zle -N fzf_killps; bindkey '^Q' fzf_killps

fzf_cd() {
  zle -I
  local find_cmd="find \${1:-*} -path '*/\.*' -prune -o -type d -print 2>/dev/null"
  local preview_cmd="tree -C {} | head -100"
  DIR=$(eval "$find_cmd" | fzf --height 50% --layout=reverse --border=rounded --preview "$preview_cmd")
  if [ -n "$DIR" ]; then
      cd "$DIR"
      zle reset-prompt
  fi
}
zle -N fzf_cd
bindkey '^E' fzf_cd
# }}}
#-------- Emacs Mode {{{
#------------------------------------------------------
# enable emacs mode on commmand line
# bindkey -e

# use text editor to edit commands
# autoload -U edit-command-line
# zle -N edit-command-line
# bindkey '\C-x\C-e' edit-command-line

# }}}
#-------- History {{{
#------------------------------------------------------
HISTFILE=~/.zsh_history
if [[ ! -f "$HISTFILE" ]]; then
  touch "$HISTFILE"
fi

# Fix corruption 
_auto_fix_zsh_history

# History settings
HISTSIZE=100000          # Number of commands to keep in memory (file was at 9.5k of 10k)
SAVEHIST=100000          # Number of commands to save to the history file
setopt append_history    # Append commands to the history file
setopt extended_history  # Save timestamps along with commands
setopt hist_ignore_dups  # Don't save consecutive duplicates
setopt hist_ignore_all_dups # Don't keep any duplicate commands
setopt share_history     # Share history across sessions
setopt INC_APPEND_HISTORY     # Write to history immediately, not on shell exit
setopt SHARE_HISTORY          # Share history across shell sessions atomically
setopt hist_save_no_dups      # Never write duplicates to the file
setopt hist_find_no_dups      # Skip duplicates when searching
setopt hist_reduce_blanks     # Normalise whitespace so near-identical commands dedupe
# (HISTIGNORE was removed: it is bash-only and did nothing in zsh)
# }}}
#-------- Empty {{{
#------------------------------------------------------
#


# }}}

#-------- Autocomplete Custom {{{
#------------------------------------------------------
# autocomplete surfraw bookmarks
# usage: srb <bookmark_name>
_cmpl_surfraw() { reply=($(awk 'NF != 0 && !/^#/ {print $1}' ~/.config/surfraw/bookmarks | grep -v '^-' | grep -v '^}' | grep -v '^/' | sort -n)) ;}
compctl -K _cmpl_surfraw srb srg
alias srb='surfraw -browser=$BROWSERCLI'          # use for surfraw bookmarks (CLI)
alias srg='surfraw -browser=$BROWSER'             # use for surfraw bookmarks (GUI)


_cmpl_redpill() {
    reply=($(ls -1 ~/.config/redpill))
}
compctl -K _cmpl_redpill redpill

# bleachbitcli
_cmpl_bleachbit() {
	reply=($(bleachbit -l | cut -d' ' -f1))
}
compctl -K _cmpl_bleachbit bleachbit

# playonlinux
_cmpl_playonlinux() {
	myarray=($(ls ~/.PlayOnLinux/shortcuts | sed 's:\ :\\\ :g'))
	reply=(printf "%s\n" ${myarray[@]})
	# reply=(${myarray[@]})
}
compctl -K _cmpl_playonlinux playonlinux


# fzf_surfraw() { zle -I; surfraw $(cat ~/.config/surfraw/bookmarks | fzf | awk 'NF != 0 && !/^#/ {print $1}' ) ; }; zle -N fzf_surfraw; 💩💩bindkey '^W' fzf_surfraw

# add sudo in front of current command
# https://www.reddit.com/r/zsh/comments/4b2lyj/send_a_simulated_keypress_from_zle_script_to/
sudo_ (){
    BUFFER="sudo $BUFFER"
    CURSOR=$#BUFFER
}
zle -N sudo_
bindkey "^f" sudo_


# }}}
#--------------------------------------------------------------------------
#http://jaredforsyth.com/blog/2010/may/30/easy-zsh-auto-completion/
## http://zshwiki.org/home/examples/compctl

# ZSH completions# {{{
# compdef _pids cpulimit
# setopt completealiases

# calibredb
# _cmpl_calibredb() {
# alias -g search="list -s"
#
#     reply=(add remove search)
# }
# compctl -K _cmpl_calibredb cmx-comic cmx-dojinshi cmx-eurotica cmx-hanime cmx-normal cmx-textbook $@

# fzf_playonlinux_run() { zle -I; playonlinux --run $(ls -1 ~/.PlayOnLinux/shortcuts | fzf) ; }; zle -N fzf_playonlinux_run; bindkey '^P' fzf_playonlinux_run

# fzf_hotkey_playonlinux() { zle -I; @dmenu ; }; zle -N fzf_hotkey_playonlinux; bindkey '^ ' fzf_hotkey_playonlinux

# fzf_surfraw() { zle -I; surfraw $(awk 'NF > 0' ~/.config/surfraw/bookmarks | fzf | awk 'NF != 0 && !/^#/ {print $1}' ) ; }; zle -N fzf_surfraw; bindkey '^W' fzf_surfraw

	# reply=($(awk 'NF != 0 && !/^#/ {print $1}' ~/.config/surfraw/bookmarks | sort -n))
# }}}

# hp: you define a function, you make a widget out of it with zle -N funcname, then you  bind that
# slmenukey() { zle -I; xe ; }; zle -N slmenukey; bindkey '^F' slmenukey
#hw() { zle -I; echo hello world; }; zle -N hw; bindkey '^[[4~' hw
#bindkey -s '^[[4~' 'echo hello\n'


# bindkey -s '^O' "fzf-dmenu\n"

bindkey -s '^O' "fzf-dmenu\n"

__fzf_nova__() {
    $HOME/.scripts/fzf-nova/fzf-nova
}

zle     -N   __fzf_nova__

bindkey '^P' __fzf_nova__

__fzf_speed__() {
    $HOME/.scripts/fzf-speed/fzf-speed
}

zle     -N  __fzf_speed__

bindkey '^U' __fzf_speed__

# disable zsh autocorrect
# https://coderwall.com/p/jaoypq
# unsetopt correct_all

# ----------------------------

# Autoload screen if we aren't in it.  (Thanks Fjord!)
# if [[ $STY = '' ]] then screen -xR; fi


# #-------- Options {{{
# #------------------------------------------------------
# # http://linux.die.net/man/1/zshoptions
#
# # Options
# # http://stackoverflow.com/a/171564
setopt AUTO_CD           # instead of 'cd folder' if you could just type 'folder'
# setopt MULTIOS           # now we can pipe to multiple outputs!
# setopt CORRECT           # spell check commands!  (Sometimes annoying)
setopt AUTO_PUSHD        # This makes cd=pushd
# setopt AUTO_NAME_DIRS    # This will use named dirs when possible
#
# # If we have a glob this will expand it
# setopt GLOB_COMPLETE
# setopt PUSHD_MINUS
#
# # No more annoying pushd messages...
# # setopt PUSHD_SILENT
#
# # blank pushd goes to home
# setopt PUSHD_TO_HOME
#
# # this will ignore multiple directories for the stack.  Useful?  I dunno.
# setopt PUSHD_IGNORE_DUPS
#
# # 10 second wait if you do something that will delete everything.  I wish I'd had this before...
# setopt RM_STAR_WAIT
#
# # use magic (this is default, but it can't hurt!)
# setopt ZLE
#
# setopt NO_HUP
#
# setopt VI
#
# # only fools wouldn't do this ;-)
# export EDITOR="vi"
#
#
# setopt IGNORE_EOF
#
# # If I could disable Ctrl-s completely I would!
# setopt NO_FLOW_CONTROL
#
# # beeps are annoying
# setopt NO_BEEP
#
# # Keep echo "station" > station from clobbering station
# setopt NO_CLOBBER
#
# # Case insensitive globbing
# setopt NO_CASE_GLOB
#
# # Be Reasonable!
# setopt NUMERIC_GLOB_SORT
#
# # I don't know why I never set this before.
# setopt EXTENDED_GLOB
#
# # hows about arrays be awesome?  (that is, frew${cool}frew has frew surrounding all the variables, not just first and last
# setopt RC_EXPAND_PARAM
#
# #
#
export LS_COLORS="di=1;36:ln=1;35:ex=1;32:ow=1;36:*.txt=0;33:*.md=0;36:*.sh=0;32:*.py=0;34:*.js=0;33:*.jpg=0;35:*.png=0;37:*.gif=0;35:*.zip=0;37:*.tar=0;36:*.tar.gz=0;33:*.mp3=0;35:*.wav=0;31:*.mp4=0;32:*.mkv=0;31:*.log=0;30:*.conf=0;37"
# # }}}
#-------- Empty {{{
#------------------------------------------------------
#


# }}}
#-------- Empty {{{
#------------------------------------------------------
#


# }}}
#-------- Empty {{{
#------------------------------------------------------
#


# }}}
#-------- Empty {{{
#------------------------------------------------------
#


# }}}




# #{{{ Completion Stuff
#
# bindkey -M viins '\C-i' complete-word
#
# # Faster! (?)
# zstyle ':completion::complete:*' use-cache 1
#
# # case insensitive completion
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
#
# zstyle ':completion:*' verbose yes
# zstyle ':completion:*:descriptions' format '%B%d%b'
# zstyle ':completion:*:messages' format '%d'
# zstyle ':completion:*:warnings' format 'No matches for: %d'
# zstyle ':completion:*' group-name ''
# #zstyle ':completion:*' completer _oldlist _expand _force_rehash _complete
# zstyle ':completion:*' completer _expand _force_rehash _complete _approximate _ignored
#
# # generate descriptions with magic.
# zstyle ':completion:*' auto-description 'specify: %d'
#
# # Don't prompt for a huge list, page it!
# zstyle ':completion:*:default' list-prompt '%S%M matches%s'
#
# # Don't prompt for a huge list, menu it!
# zstyle ':completion:*:default' menu 'select=0'
#
# # Have the newer files last so I see them first
# zstyle ':completion:*' file-sort modification reverse
#
# # color code completion!!!!  Wohoo!
# zstyle ':completion:*' list-colors "=(#b) #([0-9]#)*=36=31"
#
# unsetopt LIST_AMBIGUOUS
# setopt  COMPLETE_IN_WORD
#
# # Separate man page sections.  Neat.
# zstyle ':completion:*:manuals' separate-sections true
#
# # Egomaniac!
# zstyle ':completion:*' list-separator 'fREW'
#
# # complete with a menu for xwindow ids
# zstyle ':completion:*:windows' menu on=0
# zstyle ':completion:*:expand:*' tag-order all-expansions
#
# # more errors allowed for large words and fewer for small words
# zstyle ':completion:*:approximate:*' max-errors 'reply=(  $((  ($#PREFIX+$#SUFFIX)/3  ))  )'
#
# # Errors format
# zstyle ':completion:*:corrections' format '%B%d (errors %e)%b'
#
# # Don't complete stuff already on the line
# zstyle ':completion::*:(rm|vi):*' ignore-line true
#
# # Don't complete directory we are already in (../here)
# zstyle ':completion:*' ignore-parents parent pwd
#
# zstyle ':completion::approximate*:*' prefix-needed false
#
# #}}}

# #{{{ Key bindings
#
# # Who doesn't want home and end to work?
# bindkey '\e[1~' beginning-of-line
# bindkey '\e[4~' end-of-line
#
# # Incremental search is elite!
# bindkey -M vicmd "/" history-incremental-search-backward
# bindkey -M vicmd "?" history-incremental-search-forward
#
# # Search based on what you typed in already
# bindkey -M vicmd "//" history-beginning-search-backward
# bindkey -M vicmd "??" history-beginning-search-forward
#
# bindkey "\eOP" run-help
#
# # oh wow!  This is killer...  try it!
# bindkey -M vicmd "q" push-line
#
# # Ensure that arrow keys work as they should
# bindkey '\e[A' up-line-or-history
# bindkey '\e[B' down-line-or-history
#
# bindkey '\eOA' up-line-or-history
# bindkey '\eOB' down-line-or-history
#
# bindkey '\e[C' forward-char
# bindkey '\e[D' backward-char
#
# bindkey '\eOC' forward-char
# bindkey '\eOD' backward-char
#
# bindkey -M viins 'jj' vi-cmd-mode
# bindkey -M vicmd 'u' undo
#
# # Rebind the insert key.  I really can't stand what it currently does.
# bindkey '\e[2~' overwrite-mode
#
# # Rebind the delete key. Again, useless.
# bindkey '\e[3~' delete-char
#
# bindkey -M vicmd '!' edit-command-output
#
# # it's like, space AND completion.  Gnarlbot.
# bindkey -M viins ' ' magic-space
#
# #}}}

# copy current command to clipboard (Ctrl+X)
# https://www.reddit.com/r/commandline/comments/4fjpb0/question_how_to_copy_the_command_to_clipboard/
zle -N copyx; copyx() { echo -E $BUFFER | xsel -ib }; bindkey '^X' copyx

# # ALT-I - Paste the selected entry from locate output into the command line
# fzf-locate-widget() {
#   local selected
#   if selected=$(fasd -d | fzf -q "$LBUFFER"); then
#     LBUFFER=$selected
#   fi
#   zle redisplay
# }
# zle     -N    fzf-locate-widget
# bindkey '\ei' fzf-locate-widget


vvv() {
  local file
  file="$(fasd -Rfl "$1" | fzf -1 -0 --no-sort +m)" && vi "${file}" || return 1
}

function go {
   cat ~/fav_static.lst > ~/fav.lst
   sort ~/.dir_history | uniq -c | sort -rn | cut -c 9- | head -7 >> ~/fav.lst # most frequent
   tail -5 ~/.dir_history  >>  ~/fav.lst # last used
   /bin/rm ~/.fav; dirs -c; cat ~/fav.lst | xargs -rn 1 echo pushd -n >> ~/.fav; . ~/.fav 1>/dev/null; dirs -v -l

  if (( $# > 0 )); then
     mydir=`dirs -l +$1`
     cd $mydir
  else
     echo -n 'Select the directory number in favorites: '
     read target
     if [[ $target =~ \-[0-9]+ ]]; then
        echo $target
        let target=13+$target
        mydir=`dirs -l +$target`
        cd $mydir
     elif [[ target =~ [0-9]+ ]]; then
        echo +$target
        mydir=`dirs -l +$target`
        cd $mydir
     else
        echo ERROR: wrong target $target
     fi
  fi
}

# ------ other functions {{{

__echoerr() {
    echo -e "\e[91;1m$@\e[0m"
}

detach() {
    $@ & disown
}

silent() {
    tfile="$(mktemp)"
    echo "Redirecting output to '$tfile'"
    nohup $@ > $tfile &
}

clean-dir() {
    /bin/rm -rf ".Trash-1000"
    /bin/rm -rf "\$RECYCLE.BIN"
    /bin/rm -rf "System Volume Information"
    /bin/rm -rf "pagefile.sys"
}

clean-dir-force() {
    sudo /bin/rm -rf ".Trash-1000"
    sudo /bin/rm -rf "\$RECYCLE.BIN"
    sudo /bin/rm -rf "System Volume Information"
    sudo /bin/rm -rf "pagefile.sys"
}

psearch() {
    if [ $# -gt 0 ]; then
        ps axu | grep $@[1]
    else
        echo "Please supply process name"
    fi
}

scrape() {
    if [ $# -gt 0 ]; then
        ddir="$(echo $@ | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')-$(date +'%Y-%m-%d')"
        echo -e "\e[1mWebsite \"$@\" will now be scraped\e[0m"
        echo -e "\e[1mDownload dir is \"$ddir\"\e[0m"
        echo -e "\e[2mThis will take a while since\e[0m"
        echo -e "\e[2meach request will be made in\e[0m"
        echo -e "\e[2mbetween 1 and 3 seconds\e[0m"
        echo ""
        wget -r -p -l 10 -E -k -N -w 2 --random-wait $@ -P $ddir
    else
        __echoerr "Please supply website address"
    fi
}

remetamp3() {
    filein=$@

    read -P "Title: " title
    read -P "Artist: " artist
    read -P "Album artist: " album_artist
    read -P "Album: " album
    read -P "Year: " year
    read -P "Track: " track
    read -P "Genre: " genre
    read -P "Comment: " comment

    ffmpeg -loglevel panic -i $filein \
        -metadata title=$title \
        -metadata artist=$artist \
        -metadata album_artist=$album_artist \
        -metadata album=$album \
        -metadata year=$year \
        -metadata track=$track \
        -metadata genre=$genre \
        -metadata comment=$comment \
        -c:a copy "$track. $artist - $title - out.mp3"
}

if __has nvim; then
    nvim-switch() {
        nvim_current="$(basename $(readlink ~/.config/nvim))"
        rm ~/.config/nvim
        if [[ "$nvim_current" == "monolith.nvim" ]]; then
            echo "Current configuration is $nvim_current"
            ln -sf ~/.config/despair.nvim ~/.config/nvim
        else
            echo "Current configuration is $nvim_current"
            ln -sf ~/.config/monolith.nvim ~/.config/nvim
        fi
        echo "Set Neovim configuration to $(basename $(readlink ~/.config/nvim))"
    }

    nvim-set-config() {
        if [ ! -d "$XDG_CONFIG_HOME/$@" ]; then
            echo "Supplied config directory doesn't exist"
            return 1
        fi
        rm ~/.config/nvim
        ln -sf "$XDG_CONFIG_HOME/$@" "$XDG_CONFIG_HOME/nvim"
    }

    nvmerge() {
        if ( [[ "$@" == "-h" ]] || [[ "$@" == "--help" ]] ); then
            echo "Usage:"
            echo "    nvmerge [from] [into]"
            echo ""
            echo "Description:"
            echo "    Diffs [from] and [into] and pipes output of diff"
            echo "    into neovim while setting filename to [into]"
            return 0
        fi
        if [ $# -lt 2 ]; then
            __echoerr "Must provide two files for mergins"
            return 1
        fi
        merge -A -q -p $2 $1 $2 | nvim +"file $2"
    }
fi

# }}}
# ------ Aliases {{{
# none
# }}}
# ----- Hooks {{{
[ -n "$ZSH_HOOKS_DONE" ] && return 0

export ZSH_HOOKS_DONE="yes"

__on_pwd_chage() {
    if [ -d .git ] && [ "$PWD" != "$HOME" ]; then
        __has onefetch && gitshort || git status
        echo -e "\n"
    fi
    ls
}

__starship_prompt_builder() {
    # hr "─"
    export JOB_COUNT=$( jobs | wc -l )
    [ ! -n "$(jobs)" ] && export JOB_COUNT=0

    if jobs | grep -q nvim ; then
        export STARSHIP_SHOW_NVIM=true
    else
        export STARSHIP_SHOW_NVIM=false
    fi

    if ( [ $STARSHIP_SHOW_NVIM = false ] && [ $JOB_COUNT -gt 0 ] ) || ( [ $STARSHIP_SHOW_NVIM = true ] && [ $JOB_COUNT -gt 1 ] ); then
        export STARSHIP_SHOW_JOBS=true
    else
        export STARSHIP_SHOW_JOBS=false
    fi
}

# ZSH's history is different from bash,
# so here's my fucntion to remove
# the last item from history.
__remove_last_history_entry() {
    # This sub-checks if [ the argument passed is a number.() { ]; then
    # Thanks to @yabt on stackoverflow for this :).
    is_int() ( return $(test "$@" -eq "$@" > /dev/null 2>&1); )

    # Set history file's location
    history_file="$HISTFILE"
    history_temp_file="${history_file}.tmp"
    line_cout=$(wc -l $history_file)

    # Check if [ the user passed a number, ]; then
    # so we can delete x lines from history.
    lines_to_remove=1
    if [ $# -eq 0 ]; then
        # No arguments supplied, so set to one.
        lines_to_remove=1
    else
        # An argument passed. Check if [ it's a number. ]; then
        if [ $(is_int "${1}") ]; then
            lines_to_remove="$1"
        else
            echo "Unknown argument passed. Exiting..."
            return
        fi
    fi

    # Make the number negative, since head -n needs to be negative.
    lines_to_remove="-${lines_to_remove}"

    fc -W # write current shell's history to the history file.

    # Get the files contents minus the last entry(head -n -1 does that)
    #cat $history_file | head -n -1 &> $history_temp_file
    cat $history_file | head -n "${lines_to_remove}" &> $history_temp_file
    mv -f "$history_temp_file" "$history_file"

    fc -R # read history file.
}

settitle() {
    printf "\033k$1\033\\"
}



COMMAND_IGNORE="fg\s*.*|bg\s*.*|jobs\s*.*|history\s*.*"

__zsh_history_delete() {
    LAST_HIST=$( fc -l -1 | sed -E "s/ +[0-9]+ +//" )
    if [[ "$LAST_HIST" =~ "$COMMAND_IGNORE" ]]; then
        __remove_last_history_entry
    fi
}

# }}}
