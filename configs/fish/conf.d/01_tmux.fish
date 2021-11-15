# Shamelessly yoinked from https://github.com/pgilad/dotfiles/blob/master/fish/conf.d/600_tmux.fish

if command --search --query tmux
  and status is-login
  and not set --query TMUX
    tmux new-session
end
