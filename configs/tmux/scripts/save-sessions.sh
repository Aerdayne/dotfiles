#!/usr/bin/env bash
# Saves the tmux sessions for restore-sessions.sh: each window's layout and each pane's folder, and which sessions are
# in an Alacritty window (VS Code's terminals run tmux too, but VS Code reopens those itself). Nothing is saved while
# no Alacritty window shows tmux, so shutting down, which quits Alacritty first, keeps the save from before. If the Mac
# is still running 5 minutes after the last window closed, the windows were closed rather than shut down, so the save
# is forgotten and the next reboot reopens nothing.
#   save-sessions.sh              save now
#   save-sessions.sh --after 5    save in 5 seconds, so windows closing together (quitting Alacritty) save at most once
#   save-sessions.sh --every 900  save every 15 minutes, until the tmux server stops

save="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/sessions"
forget_after=300

# Prints the sessions an Alacritty window shows, found through each tmux client's parent processes
window_sessions() {
    tmux list-clients -F $'#{client_pid}\t#{client_session}' 2>/dev/null |
        while IFS=$'\t' read -r pid session; do
            for _ in 1 2 3; do
                pid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
                case "$(ps -o comm= -p "$pid")" in */alacritty) echo "$session"; break ;; esac
            done
        done
}

save() {
    local shown
    shown="$(window_sessions)"
    [ -n "$shown" ] || return
    [ "$(tmux show-options -gqv @restoring)" = on ] && return
    mkdir -p "$(dirname "$save")"
    {
        # Most recently used first: restore-sessions.sh gives that one to the window that restores them
        tmux list-sessions -F $'#{session_activity}\t#{session_name}' | sort -rn | cut -f2 |
            grep -Fx -f <(echo "$shown") | sed $'s/^/shown\t/'
        tmux list-windows -a -F $'window\t#{session_name}\t#{window_index}\t#{window_active}\t#{window_layout}\t#{window_name}'
        tmux list-panes -a -F $'pane\t#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_active}\t#{pane_current_path}'
    } >"$save.$$" && mv "$save.$$" "$save"
}

case "$1" in
    --after)
        sleep "$2"
        if [ -n "$(window_sessions)" ]; then
            save
        else
            # In its own process group, as tmux stops once the cleanup closes its last session; shutting down stops it
            set -m
            (sleep "$forget_after"; [ -n "$(window_sessions)" ] || rm -f "$save") </dev/null >/dev/null 2>&1 &
        fi
        ;;
    --every) while sleep "$2" && tmux has-session 2>/dev/null; do save; done ;;
    *) save ;;
esac
