#!/usr/bin/env bash
# Brings the terminal windows back after a reboot. Every new terminal window runs this before starting a tmux session,
# but it only acts in the first Alacritty window since the Mac started, if save-sessions.sh saved before that. It
# recreates the sessions that were in a window, and the named ones (from the session picker), with their windows,
# splits and each pane's folder (as a fresh shell). Then it reopens an Alacritty window for each session that had one,
# and attaches this window to the most recently used. Otherwise it exits 1, and the window starts a fresh session.

save="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/sessions"

# VS Code's terminals run this too, but only an Alacritty window restores: VS Code reopens its terminals itself
in_alacritty() {
    local pid=$$
    for _ in 1 2 3; do
        pid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
        case "$(ps -o comm= -p "$pid")" in */alacritty) return 0 ;; esac
    done
    return 1
}

[ -s "$save" ] || exit 1
booted="$(sysctl -n kern.boottime | sed -E 's/^[{] sec = ([0-9]+).*/\1/')"
[ "$(stat -f %m "$save")" -lt "$booted" ] && in_alacritty || exit 1
[ "$(tmux show-options -gqv @restoring 2>/dev/null)" = on ] && exit 1

numbered() { [[ "$1" =~ ^[0-9]+$ ]]; }
shown="$(awk -F'\t' '$1 == "shown" { print $2 }' "$save")"
wanted="$({ echo "$shown"; awk -F'\t' '$1 == "window" && $2 !~ /^[0-9]+$/ { print $2 }' "$save"; } | awk 'NF && !seen[$0]++')"

# Recreates session $1 from the save: its windows with their splits and layout, each pane a fresh shell in its folder
restore() {
    local session="$1" kind s w p active field name first
    while IFS=$'\t' read -r kind s w p active field; do
        if ! tmux has-session -t "=$session" 2>/dev/null; then
            tmux new-session -d -s "$session" -c "$field"
            first="$(tmux list-windows -t "=$session" -F '#{window_index}')"
            [ "$first" = "$w" ] || tmux move-window -s "=$session:$first" -t "=$session:$w"
        elif ! tmux list-windows -t "=$session" -F '#{window_index}' | grep -qx "$w"; then
            tmux new-window -d -t "=$session:$w" -c "$field"
        else
            # Tiled after each split, so there's room for the next one until the saved layout goes on
            tmux split-window -d -t "=$session:$w" -c "$field" && tmux select-layout -t "=$session:$w" tiled
        fi
    done < <(awk -F'\t' -v s="$session" '$1 == "pane" && $2 == s' "$save")
    while IFS=$'\t' read -r kind s w active field name; do
        tmux select-layout -t "=$session:$w" "$field"
        tmux rename-window -t "=$session:$w" "$name"
        [ "$active" = 1 ] && tmux select-window -t "=$session:$w"
    done < <(awk -F'\t' -v s="$session" '$1 == "window" && $2 == s' "$save")
    awk -F'\t' -v s="$session" '$1 == "pane" && $2 == s && $5 == 1 { print $3 "." $4 }' "$save" |
        while read -r pane; do tmux select-pane -t "=$session:$pane"; done
}

# tmux stops without a session, so this one holds it until the saved ones are back
tmux has-session 2>/dev/null || tmux new-session -d -s restoring
tmux set-option -g @restoring on
while IFS= read -r session; do
    if tmux has-session -t "=$session" 2>/dev/null; then
        # A session started since the reboot (a VS Code terminal, say) has this number: it moves to a free one
        numbered "$session" || continue
        free=0
        while tmux has-session -t "=$free" 2>/dev/null || grep -qx "$free" <<<"$wanted"; do free=$((free + 1)); done
        tmux rename-session -t "=$session" "$free"
    fi
    restore "$session"
done <<<"$wanted"
tmux kill-session -t =restoring 2>/dev/null
tmux set-option -gu @restoring 2>/dev/null

sessions=()
while IFS= read -r session; do
    tmux has-session -t "=$session" 2>/dev/null && sessions+=("$session")
done <<<"$shown"
[ ${#sessions[@]} -gt 0 ] || exit 1

# Alacritty runs the command without a login shell, so it needs tmux's full path
tmux="$(command -v tmux)"
for session in "${sessions[@]:1}"; do
    alacritty msg create-window -e "$tmux" attach-session -t "=$session"
done
exec tmux attach-session -t "=${sessions[0]}"
