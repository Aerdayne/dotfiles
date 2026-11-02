starship init fish | source
status is-interactive; and fish_config theme choose nord-fish3

# OrbStack's command-line tools (docker, orb) and shell integration
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Standalone CLI installers put their binaries here
fish_add_path --path ~/.local/bin
fish_add_path --path /opt/homebrew/opt/libpq/bin
# Server tools (postgres, initdb, pg_ctl) from the newest installed postgresql@N, after libpq's clients
set -l pg_bins /opt/homebrew/opt/postgresql@*/bin
set -q pg_bins[1]; and fish_add_path --path --append $pg_bins[-1]
fish_add_path --path /opt/homebrew/share/google-cloud-sdk/bin
