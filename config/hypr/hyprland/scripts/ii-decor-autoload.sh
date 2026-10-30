#!/bin/sh
# ii-decor's autoload from your projects folder (paths.env), if it is there
. "$HOME/.config/paths.env" 2>/dev/null
s="$PROJECTS_DIR/ii-decor/scripts/autoload.sh"
[ -x "$s" ] && exec "$s"
exit 0
