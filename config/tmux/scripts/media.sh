#!/usr/bin/env bash

# Imports
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${ROOT_DIR}/lib/core.sh"

ACCENT_COLOR="#7aa2f7"
SECONDARY_COLOR="#24283B"
BG_COLOR="#1F2335"
BG_BAR="#15161e"
TIME_COLOR="#414868"

if [[ $1 =~ ^[[:digit:]]+$ ]]; then
  MAX_TITLE_WIDTH=20
else
  MAX_TITLE_WIDTH=$(($(tmux display -p '#{window_width}' 2>/dev/null || echo 120) - 130))
fi

MAX_TITLE_WIDTH=25

if cmus-remote -Q >/dev/null 2>/dev/null; then
  CMUS_STATUS=$(cmus-remote -Q)
  STATUS=$(echo "$CMUS_STATUS" | awk '/status/ {print $2}')
  ARTIST=$(echo "$CMUS_STATUS" | awk '/tag artist/ {print $3}')
  TITLE=$(echo "$CMUS_STATUS" | awk '/tag title/ {print $3}')
  DURATION=$(echo "$CMUS_STATUS" | awk '/duration/ {print $2}')
  POSITION=$(echo "$CMUS_STATUS" | awk '/position/ {print $2}')

  P_MIN=$(printf '%02d' $((POSITION / 60)))
  P_SEC=$(printf '%02d' $((POSITION % 60)))

  D_MIN=$(printf '%02d' $((DURATION / 60)))
  D_SEC=$(printf '%02d' $((DURATION % 60)))
  TIME="[$P_MIN:$P_SEC / $D_MIN:$D_SEC]"

  if [ "$D_SEC" = "-1" ]; then
    TIME="[ $P_MIN:$P_SEC]"
  fi

  if [ -n "$TITLE" ]; then
    if [ "$STATUS" = "playing" ]; then
      PLAY_STATE="$OUTPUT"
    else
      PLAY_STATE="$OUTPUT"
    fi
    OUTPUT="$PLAY_STATE $TITLE"
  else
    OUTPUT=''
  fi
fi

if [ "${#OUTPUT}" -ge $MAX_TITLE_WIDTH ]; then
  OUTPUT="$PLAY_STATE ${TITLE:0:$MAX_TITLE_WIDTH-1}"
  OUTPUT="${OUTPUT%"${OUTPUT##*[![:space:]]}"}…"
fi

if [ -z "$OUTPUT" ]; then
  echo "$OUTPUT #[fg=green,bg=default]"
else
  OUT=" $OUTPUT $TIME "
  ONLY_OUT=" $OUTPUT "
  TIME_INDEX=${#ONLY_OUT}
  OUTPUT_LENGTH=${#OUT}
  PERCENT=$((POSITION * 100 / DURATION))
  PROGRESS=$((OUTPUT_LENGTH * PERCENT / 100))
  O=" $OUTPUT"

  if [ $PROGRESS -le $TIME_INDEX ]; then
    echo "#[nobold,fg=$BG_COLOR,bg=$ACCENT_COLOR]${O:0:PROGRESS}#[fg=$ACCENT_COLOR,bg=$BG_BAR]${O:PROGRESS:TIME_INDEX} #[fg=$TIME_COLOR,bg=$BG_BAR]$TIME "
  else
    DIFF=$((PROGRESS - TIME_INDEX))
    echo "#[nobold,fg=$BG_COLOR,bg=$ACCENT_COLOR]${O:0:TIME_INDEX} #[fg=$BG_BAR,bg=$ACCENT_COLOR]${OUT:TIME_INDEX:DIFF}#[fg=$TIME_COLOR,bg=$BG_BAR]${OUT:PROGRESS}"
  fi
fi
