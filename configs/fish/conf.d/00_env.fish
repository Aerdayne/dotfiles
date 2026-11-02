set -xg fish_greeting

set -xg fish_emoji_width 1
set -xg fish_ambiguous_width 1

set -xg LANG en_US.UTF-8
set -xg LC_ALL en_US.UTF-8

# Homebrew's bin folders go first, so its git, openssl and bash are used rather than the older ones macOS
# ships; this also sets HOMEBREW_PREFIX and the man page paths
/opt/homebrew/bin/brew shellenv fish | source
fish_add_path --path ~/.cargo/bin
