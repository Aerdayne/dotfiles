direnv hook fish | source
starship init fish | source

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Standalone CLI installers put their binaries here
fish_add_path --path ~/.local/bin
fish_add_path --path /opt/homebrew/opt/libpq/bin
# Server tools (postgres, initdb, pg_ctl) from the newest installed postgresql@N, after libpq's clients
set -l pg_bins /opt/homebrew/opt/postgresql@*/bin
set -q pg_bins[1]; and fish_add_path --path --append $pg_bins[-1]
fish_add_path --path /opt/homebrew/share/google-cloud-sdk/bin
