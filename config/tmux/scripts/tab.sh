#!/bin/bash

# Get window information passed by tmux
window_name="$1"
window_index="$2"
window_flags="$3"

# Colors
CYAN="#[fg=cyan]"
GREY="#[fg=colour8]"
YELLOW="#[fg=yellow]"
RED="#[fg=red]"
NC="#[fg=default]"

# Icons
CIRCLE=""        # Inactive
FILLED_CIRCLE="" # Active
FULLSCREEN=""    # Zoomed
BELL=""          # Bell/activity
LOCK=""          # Pane locked
STAR=""          # Marked window
ARROW_LEFT=""
ARROW_RIGHT=""

# Debugging output
echo "Window Name: $window_name, Window Index: $window_index, Window Flags: $window_flags" >>/tmp/tmux_debug.log

# Base formatting based on window state
if [[ "$window_flags" =~ "-" ]]; then
	# Inactive window
	color="$GREY"
	icon="$CIRCLE"
else
	# Active window
	color="$CYAN"
	icon="$FILLED_CIRCLE"
fi

# Additional status indicators
extra=""
# Zoomed status
[[ "$window_flags" =~ "Z" ]] && extra="${extra}${YELLOW}${FULLSCREEN}"

# Activity/bell status
[[ "$window_flags" =~ "#" ]] && extra="${extra}${RED}${BELL}"

# Last window (useful for navigation)
[[ "$window_flags" =~ "~" ]] && extra="${extra}${GREY}${STAR}"

# Window number
index_display="${NC}[${color}${window_index}${NC}]"

# Final output
echo -n "${color}${ARROW_LEFT}${NC} ${color}${icon} ${window_name}${extra} ${index_display}${NC} ${color}${ARROW_RIGHT}${NC}"
