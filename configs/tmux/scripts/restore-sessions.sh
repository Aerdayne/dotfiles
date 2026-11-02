#!/usr/bin/env bash
# Brings the terminal windows back after a reboot. Every new terminal window runs this before starting a tmux session,
# but it only acts in one that opens while no window shows tmux and there's a save from save-sessions.sh: it restores
# the saved sessions with tmux-resurrect (each pane a fresh shell in its folder), opens an Alacritty window for each
# session that had one, and attaches this window to the most recently used. Otherwise it exits 1, and the window
# starts a fresh session.

resurrect=~/.tmux/plugins/tmux-resurrect/scripts/restore.sh
windows="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/windows"

[ -x "$resurrect" ] && [ -s "$windows" ] || exit 1
[ -z "$(tmux list-clients 2>/dev/null)" ] || exit 1
[ "$(tmux show-options -gqv @restoring 2>/dev/null)" = on ] && exit 1

# resurrect runs inside tmux, which needs a session to keep running; this one goes once the saved ones are back
tmux has-session 2>/dev/null || tmux new-session -d -s restoring
tmux set-option -g @restoring on
tmux run-shell "$resurrect" >/dev/null 2>&1
tmux kill-session -t =restoring 2>/dev/null
tmux set-option -gu @restoring 2>/dev/null

sessions=()
while IFS= read -r session; do
    tmux has-session -t "=$session" 2>/dev/null && sessions+=("$session")
done <"$windows"
[ ${#sessions[@]} -gt 0 ] || exit 1

# Alacritty runs the command without a login shell, so it needs tmux's full path
tmux="$(command -v tmux)"
for session in "${sessions[@]:1}"; do
    alacritty msg create-window -e "$tmux" attach-session -t "=$session"
done
exec tmux attach-session -t "=${sessions[0]}"
