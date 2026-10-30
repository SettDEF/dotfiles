#!/bin/bash
export TMUX="/tmp/tmux-tor"
tmux start-server
tmux -f ~/.config/tmux/tor.conf new-session -n "tor" "proxychains -q nmap -sV -Pn 192.168.1.100; $SHELL"
