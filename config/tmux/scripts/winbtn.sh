#!/bin/bash
# Window buttons in the tmux status bar. WezTerm is registered as "integrated"
# in ~/.config/hypr/ii-decor.d/wezterm.json, so ii-decor gives it no title bar;
# these do what its buttons would, through the shared ii-decor-btn helper.
#   winbtn.sh <win-close|win-max|win-min> <client pid>
case $1 in
  win-close) act=close ;;
  win-max)   act=maximize ;;
  win-min)   act=minimize ;;
  *) exit 2 ;;
esac
exec ~/.local/bin/ii-decor-btn "$act" "$2"
