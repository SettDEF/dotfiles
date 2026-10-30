# Directory navigation
alias ..='cd ..'  # Go up one directory
alias ...='cd ../..'  # Go up two directories
alias ....='cd ../../..'  # Go up three directories
alias ~='cd ~'  # Go to home directory
alias cdup='cd ..'  # Alias for going up one directory
alias cd.='cd -'  # Go to the previous directory

# Directory listing
alias l='ls -CF'  # List in columns, append indicators
alias ls='ls --color'
alias la='ls -A'  # List all files, including hidden (except . and ..)
alias ll='ls -alF'  # Long list format, show almost all files, append indicators
alias lsd='ls -l | grep "^d"'  # List only directories
alias ltr='ls -ltr'  # List sorted by modification time, oldest last

# File operations
# alias cp='cp -iv'  # Copy files with confirmation and verbose output
# alias mv='mv -iv'  # Move files with confirmation and verbose output
# alias rm='rm -iv'  # Remove files with confirmation and verbose output
# alias mkdir='mkdir -pv'  # Create directories recursively, with verbose output

# Disk usage
alias df='df -Th'  # Display disk space usage with human-readable sizes and filesystem type
alias du='du -ach | sort -rh | less'  # Display directory sizes, sorted, with human-readable sizes

# Process management
alias psg='ps aux | grep -v grep | grep -i'  # Search for a process by name

# System info
alias free='free -m'  # Display memory usage in megabytes
alias myip='curl ipinfo.io/ip'  # Show public IP address

# Networking
alias ports='netstat -tulanp'  # Show listening ports

# Searching
alias findfile='find . -type f -name'  # Find files by name in the current directory
alias finddir='find . -type d -name'  # Find directories by name in the current directory
alias grep='grep --color=auto'  # Grep with color highlighting
alias fgrep='fgrep --color=auto'  # Fixed-string grep with color highlighting
alias egrep='egrep --color=auto'  # Extended regex grep with color highlighting

# General shortcuts
alias c='clear'  # Clear the terminal screen
alias e='exit'  # Exit the terminal session
alias q='exit'  # Exit the terminal session
alias h='history'  # Show command history
alias reload!='source ~/.zshrc'  # Reload the shell configuration file
alias cls='clear'  # Clear the terminal screen

# Package management (for Debian-based systems)
alias update='sudo apt update && sudo apt upgrade'  # Update package lists and upgrade installed packages
alias install='sudo apt install'  # Install a package
alias remove='sudo apt remove'  # Remove a package

# Miscellaneous
alias htop='sudo htop'  # Run htop with elevated privileges
alias top='htop'  # Alias for htop
alias ping='ping -c 5'  # Send 5 ICMP packets to test network connection
alias dfu='df -h'  # Display disk space usage with human-readable sizes
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python -'  # Run a speed test
alias g='git'  # Shorter alias for git
alias d='docker'  # Shorter alias for docker


# git
alias ga='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gau='git add --update'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gc='git commit -v'
alias gca='git commit -v -a'
alias gcam='git commit -a -m'
alias gcb='git checkout -b'
alias gcf='git config --list'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean -id'
alias gcm='git checkout master'
alias gcd='git checkout develop'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcom='git checkout master'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gd='git diff'
alias gdc='git diff --cached'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gfo='git fetch origin'
alias gfpull='git pull --ff-only'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ggpull='git pull origin $(git_current_branch)'
alias ggpush='git push origin $(git_current_branch)'
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias git-svn-dcommit-push='git svn dcommit && git push github master:svntrunk'
alias gk='\gitk --all --branches'
alias gke='\gitk --all $(git log -g --pretty=%h)'
alias gl='git pull'
alias glg='git log --stat'
alias glgp='git log --stat -p'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glo='git log --oneline --decorate'
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias glols="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --stat"
alias glp='_git_log_prettily'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gmt='git mergetool --no-prompt'
alias gpoat='git push origin --all && git push origin --tags'
alias gpod='git push origin develop'
alias gpoh='git push origin master'
alias gpom='git push origin master'
alias gpristine='git reset --hard && git clean -dfx'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gpu='git push'
alias gpv='git push -v'
alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase -i'
alias grbm='git rebase master'
alias grbs='git rebase --skip'
alias grev='git revert'
alias grh='git reset'
alias grhh='git reset --hard'
alias grm='git rm'
alias grmc='git rm --cached'
alias grmv='git remote rename'
alias grrm='git remote remove'
alias grset='git remote set-url'
alias grt='cd $(git rev-parse --show-toplevel || echo ".")'
alias gru='git reset --'
alias grup='git remote update'
alias grv='git remote -v'
alias gsb='git status -sb'
alias gsd='git svn dcommit'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsst='git stash'
alias gssta='git stash apply'
alias gsstc='git stash clear'
alias gsstd='git stash drop'
alias gsstl='git stash list'
alias gssts='git stash show --text'
alias gst='git status'
alias gsta='git stash save'
alias gstaa='git stash apply --all'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gsu='git submodule update'
alias gts='git tag -s'
alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
alias gup='git pull --rebase'
alias gupv='git pull --rebase -v'
alias gvt='git verify-tag'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gsearch='git grep'
alias gpub='git publish'
alias gundo='git reset HEAD~1 --mixed'
alias gwc='git whatchanged'
alias gdrc='git diff --cached HEAD^'
alias glp='git log -p'
alias gcln='git clean -n'
alias gcof='git checkout --'
alias grhh='git reset --hard HEAD'
alias gundo='git reset HEAD~1 --mixed'
alias gmff='git merge --no-ff'
alias gmt='git mergetool'
alias gblg='git blame -L'
alias gwh='git whatchanged'
alias greflog='git reflog'
alias gcp='git cherry-pick'
alias gcpc='git cherry-pick --continue'
alias gcpa='git cherry-pick --abort'
alias gcpca='git cherry-pick --continue --abort'
alias gcbm='git checkout -B'
alias grs='git reset --soft'
alias grm='git rm'
alias grmc='git rm --cached'
alias grc='git rebase --continue'
alias gra='git rebase --abort'
alias gsd='git svn dcommit'
alias gsp='git show --pretty'
alias gsw='git switch'
alias gsd='git svn dcommit'
alias gst='git stash'
