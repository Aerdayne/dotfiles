#!/usr/bin/env bash
# Saves the tmux sessions for restore-sessions.sh: tmux-resurrect's snapshot of them, and which ones are in a window.
# Nothing is saved while no window shows tmux, so quitting Alacritty or logging out keeps the save from before.
#   save-sessions.sh              save now
#   save-sessions.sh --after 5    save in 5 seconds, so windows closing together (quitting Alacritty) save at most once
#   save-sessions.sh --every 900  save every 15 minutes, until the tmux server stops

resurrect=~/.tmux/plugins/tmux-resurrect/scripts/save.sh
windows="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/windows"
lock="${TMPDIR:-/tmp}/tmux-save-sessions.lock"

save() {
    [ -x "$resurrect" ] || return
    [ -n "$(tmux list-clients 2>/dev/null)" ] || return
    [ "$(tmux show-options -gqv @restoring)" = on ] && return
    shlock -f "$lock" -p $$ || return
    "$resurrect" quiet
    # Most recently used first: restore-sessions.sh gives that one to the window that restores them
    mkdir -p "$(dirname "$windows")"
    tmux list-sessions -F $'#{session_activity}\t#{session_attached}\t#{session_name}' |
        sort -rn | awk -F'\t' '$2 > 0 { print $3 }' >"$windows.new" && mv "$windows.new" "$windows"
    rm -f "$lock"
}

case "$1" in
    --after) sleep "$2"; save ;;
    --every) while sleep "$2" && tmux has-session 2>/dev/null; do save; done ;;
    *) save ;;
esac
