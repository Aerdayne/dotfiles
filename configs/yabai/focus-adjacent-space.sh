#!/usr/bin/env bash

# Focuses the previous/next space in physical left-to-right order across all displays.
# yabai's own `space --focus prev/next` follows macOS's display list, which puts the main display
# first, so it jumps to the wrong monitor (or stops) when the displays aren't arranged in that order,
# e.g. a MacBook placed to the left of the main external monitor.
#
# Usage: focus-adjacent-space.sh prev|next

case "$1" in
    prev) step=-1 ;;
    next) step=1 ;;
    *)
        echo "usage: $0 prev|next" >&2
        exit 1
        ;;
esac

target="$(jq -rn --argjson step "$step" \
    --argjson displays "$(yabai -m query --displays)" \
    --argjson spaces "$(yabai -m query --spaces)" '
    ($displays | map({key: (.index | tostring), value: .frame}) | from_entries) as $frame
    | $spaces
    | sort_by([$frame[.display | tostring].x, $frame[.display | tostring].y, .index])
    | (to_entries | map(select(.value."has-focus")) | first | .key) as $i
    | if $i == null or $i + $step < 0 or $i + $step >= length then empty else .[$i + $step].index end')"

[ -n "$target" ] && yabai -m space --focus "$target"
