#!/usr/bin/env bash

# Focuses the next tmux pane in a direction, or the next window once the pane is at that edge.
# A tmux command without a target acts on whichever terminal last had input, not the focused one,
# so the session comes from the focused window's title, which tmux sets to "SESSION:WINDOW:…".
#
# Usage: focus-pane-or-window.sh west|south|north|east

case "$1" in
    west) flag=-L edge=left ;;
    south) flag=-D edge=bottom ;;
    north) flag=-U edge=top ;;
    east) flag=-R edge=right ;;
    *)
        echo "usage: $0 west|south|north|east" >&2
        exit 1
        ;;
esac

session="$(yabai -m query --windows --window | jq -r '.title | split(":")[0]')"
if tmux has-session -t "=$session" 2>/dev/null &&
    [ "$(tmux display-message -p -t "=$session:" "#{pane_at_$edge}")" = 0 ]; then
    tmux select-pane -t "=$session:" "$flag"
else
    yabai -m window --focus "$1"
fi
