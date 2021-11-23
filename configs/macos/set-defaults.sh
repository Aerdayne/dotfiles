# !/usr/bin/env bash

set -e

osascript -e 'tell application "System Preferences" to quit'

osascript <<EOF
tell application "System Events"
    tell current desktop
        set pictures folder to "/Users/aerdayne/wallpapers"
        set picture rotation to 1
        set random order to true
        set change interval to 3600.0
    end tell
end tell
EOF

sudo --validate

# https://www.defaults-write.com/

# --------------------------------------------------------------------

# Disable dashboard on early MacOS versions
defaults write com.apple.dashboard mcx-disabled -boolean true

# Enable battery percentage, disable time
defaults write com.apple.menuextra.battery ShowPercent -string "YES"
defaults write com.apple.menuextra.battery ShowTime -string "NO"

# Disable startup sound
sudo nvram SystemAudioVolume=%01
sudo nvram StartupMute=%01

# Needed for https://github.com/koekeishiya/yabai
# Disable auto rearrangement of spaces based on recency of their usage
defaults write com.apple.dock mru-spaces -bool false

# Disable rubber scrolling
defaults write -g NSScrollViewRubberbanding -int 0

# --------------------------------------------------------------------

killall Finder
killall Dock
