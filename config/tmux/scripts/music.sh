#!/usr/bin/env bash

# Imports
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${ROOT_DIR}/lib/core.sh"

# Check the global value for @tmux_show_music
SHOW_MUSIC=$(tmux show-option -gv @tmux_show_music)

# Exit if @tmux_show_music is not set to 1
if [ "$SHOW_MUSIC" != "1" ]; then
  exit 0
fi

# MPD and ncmpcpp colors
ACCENT_COLOR="#7aa2f7"
SECONDARY_COLOR="#24283B"
BG_COLOR="#1F2335"
BG_BAR="#15161e"
TIME_COLOR="#414868"

# Fetch the max title width
if [[ $1 =~ ^[[:digit:]]+$ ]]; then
  MAX_TITLE_WIDTH=$1
else
  MAX_TITLE_WIDTH=$(($(tmux display -p '#{window_width}' 2>/dev/null || echo 120) - 90))
fi

# Check for playerctl or nowplaying-cli
if command -v playerctl >/dev/null; then
  PLAYER_STATUS=$(playerctl -a metadata --format "{{status}};{{mpris:length}};{{position}};{{title}}" | grep -m1 "Playing")
  STATUS="playing"

  # If there is no playing media, check for paused media
  if [ -z "$PLAYER_STATUS" ]; then
    PLAYER_STATUS=$(playerctl -a metadata --format "{{status}};{{mpris:length}};{{position}};{{title}}" | grep -m1 "Paused")
    STATUS="paused"
  fi

  TITLE=$(echo "$PLAYER_STATUS" | cut -d';' --fields=4)
  DURATION=$(echo "$PLAYER_STATUS" | cut -d';' --fields=2)
  POSITION=$(echo "$PLAYER_STATUS" | cut -d';' --fields=3)

  # Convert position and duration to seconds from microseconds
  DURATION=$((DURATION / 1000000))
  POSITION=$((POSITION / 1000000))

  if [ "$DURATION" -eq 0 ]; then
    DURATION=-1
    POSITION=0
  fi

elif command -v nowplaying-cli >/dev/null; then
  NPCLI_PROPERTIES=(title duration elapsedTime playbackRate isAlwaysLive)
  mapfile -t NPCLI_OUTPUT < <(nowplaying-cli get "${NPCLI_PROPERTIES[@]}")
  declare -A NPCLI_VALUES
  for ((i = 0; i < ${#NPCLI_PROPERTIES[@]}; i++)); do
    [ "${NPCLI_OUTPUT[$i]}" = "null" ] && NPCLI_OUTPUT[$i]=""
    NPCLI_VALUES[${NPCLI_PROPERTIES[$i]}]="${NPCLI_OUTPUT[$i]}"
  done

  if [ -n "${NPCLI_VALUES[playbackRate]}" ] && [ "${NPCLI_VALUES[playbackRate]}" -gt 0 ]; then
    STATUS="playing"
  else
    STATUS="paused"
  fi

  TITLE="${NPCLI_VALUES[title]}"
  if [ "${NPCLI_VALUES[isAlwaysLive]}" = "1" ]; then
    DURATION=-1
    POSITION=0
  else
    DURATION=$(printf "%.0f" "${NPCLI_VALUES[duration]}")
    POSITION=$(printf "%.0f" "${NPCLI_VALUES[elapsedTime]}")
  fi

# Check for MPD and fetch song details
elif command -v mpc >/dev/null; then
  MPD_STATUS=$(mpc status | head -n 1) # Get the first line for status
  if [[ "$MPD_STATUS" =~ "playing" ]]; then
    STATUS="playing"
  else
    STATUS="paused"
  fi

  TITLE=$(mpc current) # Get the current song title
  DURATION=$(mpc | grep "([0-9]" | awk -F'[()]' '{print $2}') # Get song duration from mpc output
  POSITION=$(mpc | grep "([0-9]" | awk -F'[()]' '{print $1}') # Get current position from mpc output

  # Format duration and position in seconds (convert to seconds if necessary)
  DURATION=$((DURATION))
  POSITION=$((POSITION))

  if [ "$DURATION" -eq 0 ]; then
    DURATION=-1
    POSITION=0
  fi
fi

# Format the progress bar if we have valid data
if [ -n "$DURATION" ] && [ -n "$POSITION" ] && [ "$DURATION" -gt 0 ] && [ "$DURATION" -lt 3600 ]; then
  TIME="[$(date -d@$POSITION -u +%M:%S) / $(date -d@$DURATION -u +%M:%S)]"
else
  TIME="[--:--]"
fi

if [ -n "$TITLE" ]; then
  # Show the player state (playing or paused)
  if [ "$STATUS" = "playing" ]; then
    PLAY_STATE="░  $TITLE"
  else
    PLAY_STATE="░ 󰏤 $TITLE"
  fi

  # Truncate the title if it's too long
  if [ "${#PLAY_STATE}" -ge $MAX_TITLE_WIDTH ]; then
    PLAY_STATE="${TITLE:0:$MAX_TITLE_WIDTH-1}…"
  fi
else
  PLAY_STATE=''
fi

# Handle the output, adjusting progress and time display
if [ -z "$PLAY_STATE" ]; then
  echo "$PLAY_STATE #[fg=green,bg=default]"
else
  OUT="$PLAY_STATE $TIME"
  ONLY_OUT="$PLAY_STATE"
  TIME_INDEX=${#ONLY_OUT}
  OUTPUT_LENGTH=${#OUT}
  PERCENT=$((POSITION * 100 / DURATION))
  PROGRESS=$((OUTPUT_LENGTH * PERCENT / 100))
  O="$OUTPUT"

  if [ $PROGRESS -le $TIME_INDEX ]; then
    echo "#[nobold,fg=$BG_COLOR,bg=$ACCENT_COLOR]${O:0:PROGRESS}#[fg=$ACCENT_COLOR,bg=$BG_BAR]${O:PROGRESS:TIME_INDEX} #[fg=$TIME_COLOR,bg=$BG_BAR]$TIME "
  else
    DIFF=$((PROGRESS - TIME_INDEX))
    echo "#[nobold,fg=$BG_COLOR,bg=$ACCENT_COLOR]${O:0:TIME_INDEX} #[fg=$BG_BAR,bg=$ACCENT_COLOR]${OUT:TIME_INDEX:DIFF}#[fg=$TIME_COLOR,bg=$BG_BAR]${OUT:PROGRESS}"
  fi
fi
