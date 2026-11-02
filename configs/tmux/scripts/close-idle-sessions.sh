#!/usr/bin/env bash
# Closes what closed terminal windows leave behind: numbered sessions (each new window starts one) that no window
# shows and whose panes are all idle shells, without even a background job. Sessions shown in a window, named ones
# (from the session picker) and ones with anything running stay.

shell="$(basename "$(tmux show-options -gv default-shell)")"

# Prints "<session>\t<pane shell pids>" for each numbered session that's unseen and only has shells at a prompt
tmux list-panes -a -F $'#{session_name}\t#{session_attached}\t#{pane_current_command}\t#{pane_pid}' |
    awk -F'\t' -v shell="$shell" '
        { seen[$1] = 1; pids[$1] = pids[$1] " " $4 }
        $1 !~ /^[0-9]+$/ || $2 > 0 || $3 != shell { keep[$1] = 1 }
        END { for (session in seen) if (!(session in keep)) printf "%s\t%s\n", session, pids[session] }
    ' |
    while IFS=$'\t' read -r session pids; do
        for pid in $pids; do
            pgrep -P "$pid" >/dev/null && continue 2
        done
        tmux kill-session -t "=$session"
    done
