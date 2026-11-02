# Start a fresh tmux session in every new terminal window; pick existing sessions with prefix+f.
# The first window after a reboot reopens the windows from before instead
if command --search --query tmux
  and status is-login
  and not set --query TMUX
    ~/.tmux/scripts/restore-sessions.sh; or tmux new-session
end
