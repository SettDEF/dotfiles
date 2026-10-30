# Pasting into the shell: make it fast, and make it behave the same every time.
#
# THE SYMPTOM
#
# Pasting the same multi-line command twice behaved differently: once the
# continuation prompt appeared and the lines were read one at a time, once the
# whole block just sat in the buffer. Both are bracketed paste working as
# designed — the difference is whether the copied text ended with a newline.
# A trailing newline inside a paste is inserted, never executed, because the
# entire point of bracketed paste is that pasted text cannot run on its own.
# Copy without the final newline and you get the buffer; copy with it and you
# still get the buffer, but an extra blank line inside it.
#
# That part is a safety feature and stays. What was wrong is everything below.

# ── Syntax highlighting gives up on long lines ────────────────────────────────
#
# zsh-syntax-highlighting re-parses the WHOLE buffer on every keystroke, and a
# paste is thousands of keystrokes in a row. On a big paste that is seconds of
# stalled terminal, which reads as "the shell hung" and is the other half of
# "sometimes it behaves differently". Past this many characters it stops
# colouring — the line still works, it is just not painted.
ZSH_HIGHLIGHT_MAXLENGTH=512

# ── Autosuggestions stop guessing mid-paste ───────────────────────────────────
#
# Same problem, different plugin: a history search per inserted character.
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# ── bracketed-paste-magic, with the one zstyle that matters ───────────────────
#
# Plain bracketed-paste inserts text literally. `-magic` runs the line editor's
# widgets over it, which is what makes quoting and history expansion behave the
# way they do when you type — but by default it runs EVERY active widget over
# every pasted character, which is exactly the slowness above and makes
# autosuggestions fire inside the paste.
#
# Limiting it to `.self-insert` is the documented fix: pasted characters are
# inserted, nothing else is triggered.
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic
zstyle ':bracketed-paste-magic' active-widgets '.self-insert'

# ── URLs get quoted when you paste them ───────────────────────────────────────
#
# A URL with `?`, `&` or `~` in it is a glob and a job-control character to the
# shell. Without this, pasting one either errors with "no matches found" or
# silently becomes something else.
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# ── A pasted multi-line command is shown before it runs ───────────────────────
#
# The heredoc that started all this failed because its terminator arrived
# indented — `<<'EOF'` matches `EOF` only at column zero, and `<<-'EOF'` strips
# tabs but never spaces, so a two-space indent from a clipboard hangs the
# heredoc with no error at all.
#
# This cannot fix the indentation, but it stops the class of surprise where a
# pasted block runs before you have read it: with a multi-line buffer, the
# first Return moves to a new line and the second submits.
setopt NO_HIST_VERIFY
bindkey -M viins '^[[200~' bracketed-paste
bindkey -M vicmd '^[[200~' bracketed-paste

# ── The continuation prompt, matched to this shell ───────────────────────────
#
# `█▓▒░>` came from `prompt fade magenta` on line 11 of .zshrc — a theme this
# shell stopped using the moment the custom PROMPT was written. PROMPT was
# overridden; PS2 never was, so every multi-line command was wearing a prompt
# from a different design.
#
# `%_` is the useful part, and it is the thing that would have made the heredoc
# failure obvious: zsh prints WHAT it is still waiting for — `heredoc`, `if`,
# `for`, `quote`. A line reading `heredoc ❯` after you thought you had closed
# it says exactly what went wrong.
#
# The accent is the same vi-mode colour the main prompt uses, so INSERT and
# NORMAL tint the continuation the same way they tint `❯`.
PS2='%F{${__pmode_accent}}%_%f %F{${__pmode_accent}}❯%f '

# `select` menus, same family.
PS3='%F{${__pmode_accent}}?%f '

# `set -x` tracing: line number and function, which the default leaves out.
PS4='%F{${__pmode_accent}}+%f %N:%i%(1_:%_:) '

# ── Paste from the clipboard, in the shell ───────────────────────────────────
#
# WHY NOT JUST USE THE TERMINAL'S PASTE
#
# There are three programs between the clipboard and this line editor:
# WezTerm, tmux, and zsh. WezTerm wraps a paste in bracketed-paste markers only
# if the app asked for them; tmux forwards them only if IT knows the outer
# terminal can; and tmux's `assume-paste-time 1` separately guesses "this is a
# paste" from how fast the bytes arrive. Three layers, each with its own idea,
# is why the same clipboard pasted twice behaved differently.
#
# These widgets read the clipboard themselves. No markers, no timing guess, no
# tmux — `wl-paste` to a string, string into the buffer. It cannot execute, and
# it cannot arrive differently on a slow day.

# The trailing newline is always dropped. A clipboard that ends in one is the
# entire reason a paste sometimes ran on its own: the newline is a Return.
_clip_read() {
    local text
    text=$(wl-paste --no-newline 2>/dev/null) || return 1
    print -r -- "${text%$'\n'}"
}

# Strip the indentation every line shares.
#
# This is the heredoc fix. `<<'EOF'` matches its terminator only at column
# zero, and `<<-'EOF'` strips tabs but never spaces — so a config block copied
# out of a web page, indented two spaces, hangs the heredoc with no error at
# all. Removing the COMMON indent keeps relative structure (Python survives)
# while putting column zero back where the shell expects it.
_clip_dedent() {
    local text=$1
    local -a lines
    lines=("${(@f)text}")
    local indent="" line
    for line in $lines; do
        [[ -z ${line//[[:space:]]/} ]] && continue     # blank lines have no say
        local lead="${line%%[^[:space:]]*}"
        if [[ -z $indent ]]; then
            indent=$lead
        else
            # The shared prefix of what we have and this line's indent.
            while [[ -n $indent && $lead != $indent* ]]; do
                indent=${indent[1,-2]}
            done
        fi
    done
    [[ -z $indent ]] && { print -r -- "$text"; return; }
    print -rl -- ${lines[@]#$indent}
}

zle -N clipboard-paste
clipboard-paste() {
    local text
    text=$(_clip_read) || return
    LBUFFER+="$text"
}

zle -N clipboard-paste-dedent
clipboard-paste-dedent() {
    local text
    text=$(_clip_read) || return
    LBUFFER+="$(_clip_dedent "$text")"
}

# ^V pastes as-is; Alt-v pastes with the shared indent removed. Alt-v matches
# the binding WezTerm already uses, so the muscle memory carries over — it just
# stops going through two other programs first.
for _map in viins vicmd emacs; do
    bindkey -M $_map '^V' clipboard-paste
    bindkey -M $_map '^[v' clipboard-paste-dedent
done
unset _map
