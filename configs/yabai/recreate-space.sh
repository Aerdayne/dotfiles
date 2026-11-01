#!/usr/bin/env bash
# Replaces a desktop (the given index, or the focused one) with a fresh one, keeping its windows (in stack
# order), layout and position. Used by fix-notch-shield.sh to get rid of a black bar macOS leaves stuck
# to a desktop.

space="$(yabai -m query --spaces --space ${1:+"$1"})" || exit 1
if [ "$(jq '."is-native-fullscreen"' <<< "$space")" = true ]; then
    echo "space is a native fullscreen space, not a desktop" >&2
    exit 1
fi
index="$(jq .index <<< "$space")"
display="$(jq .display <<< "$space")"
focused="$(yabai -m query --windows --window 2> /dev/null | jq .id)"

last_on_display() { yabai -m query --spaces --display "$display" | jq '.[-1].index'; }

yabai -m space --create "$display" || exit 1
new="$(last_on_display)"
yabai -m space "$new" --layout "$(jq -r .type <<< "$space")"
# Sticky windows are on every desktop anyway; anything that fails to move is moved by macOS on destroy
yabai -m query --windows --space "$index" | jq 'map(select(."is-sticky" | not)) | sort_by(."stack-index") | .[].id' |
    while read -r window; do yabai -m window "$window" --space "$new"; done
yabai -m space "$index" --destroy || exit 1

# The destroy shifted the new desktop's index; put it back where the old one was
new="$(last_on_display)"
[ "$new" != "$index" ] && yabai -m space "$new" --move "$index"
[ "$(jq '."is-visible"' <<< "$space")" = true ] && yabai -m space --focus "$index"
[ -n "$focused" ] && yabai -m window --focus "$focused"
