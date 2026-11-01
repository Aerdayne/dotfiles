#!/usr/bin/env bash

# Keeps yabai's layout in sync when a space is dragged to another display in Mission Control.
# yabai doesn't recompute the layout of a space moved that way, so the next time the space is
# shown it snaps the windows back to the old display's coordinates, and macOS drops them onto
# that display's visible space. While Mission Control is open, this polls for spaces whose display
# changed and refreshes their layout (`--gap rel:0` changes nothing, but makes yabai recompute it).
#
# Usage: refresh-moved-spaces.sh start   # on mission_control_enter
#        refresh-moved-spaces.sh stop    # on mission_control_exit

MARKER="/tmp/yabai_${USER}_mission_control.pid"

snapshot() {
    yabai -m query --spaces | jq -c 'map({id, index, display})'
}

# Refreshes spaces whose display differs from the snapshot given in $1, prints the new snapshot
refresh_moved() {
    local current
    current="$(snapshot)" || return 1
    jq -r --argjson before "$1" \
        '.[] | . as $s | select(any($before[]; .id == $s.id and .display != $s.display)) | .index' <<< "$current" |
        while read -r index; do
            yabai -m space "$index" --gap rel:0 > /dev/null
        done
    echo "$current"
}

case "$1" in
    start)
        echo $$ > "$MARKER"
        spaces="$(snapshot)" || exit 1
        # A newer `start` overwrites the marker and `stop` removes it, either ends this loop
        while [ "$(cat "$MARKER" 2>/dev/null)" = "$$" ]; do
            sleep 0.1
            spaces="$(refresh_moved "$spaces")" || exit 1
        done
        refresh_moved "$spaces" > /dev/null
        ;;
    stop)
        rm -f "$MARKER"
        ;;
    *)
        echo "usage: $0 start|stop" >&2
        exit 1
        ;;
esac
