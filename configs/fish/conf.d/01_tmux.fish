# Start a fresh tmux session in every new terminal window; pick existing sessions with prefix+f
if command --search --query tmux
  and status is-login
  and not set --query TMUX
    tmux new-session
end
