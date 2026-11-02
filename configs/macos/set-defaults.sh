#!/usr/bin/env bash

set -e

osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

# Set desktop wallpaper folder with rotation
# Note: requires Automation permission for Terminal in
# System Settings > Privacy & Security > Automation
osascript <<EOF || echo "Warning: could not set desktop wallpaper. Set it manually in System Settings > Wallpaper."
tell application "System Events"
    tell every desktop
        set pictures folder to POSIX file "$HOME/wallpapers"
        set picture rotation to 1
        set random order to true
        set change interval to 3600.0
    end tell
end tell
EOF

sudo --validate

# Disable startup sound
sudo nvram SystemAudioVolume=%01
sudo nvram StartupMute=%01

# https://www.defaults-write.com/
# https://macos-defaults.com/
# Helpful commands:
#   defaults help
#   defaults domains
#   defaults find #{word}

defaults -currentHost write com.apple.controlcenter.plist BatteryShowPercentage -bool true # Enable battery percentage in menu bar
defaults write com.apple.dock mru-spaces -bool false # Disable auto rearrangement of spaces based on recency of their usage
defaults write -g NSScrollViewRubberbanding -int 0 # Disable rubber scrolling
defaults write -g AppleFontSmoothing -int 0 # Alacritty changelog: "`font.use_thin_strokes` config field; to use thin strokes on macOS, set `AppleFontSmoothing` to 0"

# Trackpad tap to click (both built-in and Bluetooth trackpad)
defaults write -g com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

defaults write -g com.apple.trackpad.forceClick -int 1 # Trackpad force click

# Trackpad gestures (built-in)
defaults write com.apple.AppleMultitouchTrackpad DragLock -bool false
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadHandResting -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadHorizScroll -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadPinch -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadScroll -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.AppleMultitouchTrackpad USBMouseStopsTrackpad -int 0
defaults write com.apple.AppleMultitouchTrackpad UserPreferences -int 1

# Trackpad gestures (Bluetooth/Magic Trackpad)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadHandResting -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadHorizScroll -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadMomentumScroll -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadPinch -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRotate -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadScroll -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerDoubleTapGesture -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad USBMouseStopsTrackpad -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad UserPreferences -int 1

# Dock
defaults write com.apple.dock "autohide" -bool "true" # Autohide Dock
defaults write com.apple.dock "autohide-time-modifier" -float 0 # Make Dock appear and disappear instantly
defaults write com.apple.dock "expose-animation-duration" -float 0 # Open Mission Control without its animation
defaults write com.apple.dock "mineffect" -string "scale" # Minimise windows with the quicker scale effect instead of the genie
# Reduce space transition motion (not always instant). macOS only lets terminals with Full Disk Access write these
defaults write com.apple.universalaccess reduceMotion -bool true &&
    defaults write com.apple.Accessibility ReduceMotionEnabled -bool true ||
    echo "Warning: could not turn on Reduce motion. Turn it on in System Settings > Accessibility > Display."
defaults write com.apple.dock "show-recents" -bool "false" # Hide recents from Dock

# Finder
defaults write com.apple.finder "QuitMenuItem" -bool "true" # Quit option in the Finder
defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true" # Show file extensions in the Finder
defaults write com.apple.finder "AppleShowAllFiles" -bool "true" # Show hidden files in the Finder
defaults write com.apple.finder "ShowPathbar" -bool "true" # Show path bar in the Finder
defaults write com.apple.finder "CreateDesktop" -bool "false" # Hide all icons on desktop

# Disable macOS Mission Control shortcuts that conflict with skhd
# 79/80 = Move left/right a space (ctrl+left/right), 81/82 = same with ctrl+arrow
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 "{enabled = 0;}" 80 "{enabled = 0;}" 81 "{enabled = 0;}" 82 "{enabled = 0;}"

# Switch input source with ctrl+cmd+tilde (60), disable the alternate shortcut (61)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '{ enabled = 1; value = { parameters = (96, 50, 1310720); type = standard; }; }' 61 '{enabled = 0;}'

# Keyboard
defaults write -g InitialKeyRepeat -int 25 # Delay until key repeat (375ms)
defaults write -g KeyRepeat -int 2 # Key repeat rate (~30ms between repeats)

# True Tone is switched on/off by configs/yabai/sync-true-tone.js depending on external displays

# MonitorControl: write the saved brightness back to monitors when they reconnect (dock, wake),
# instead of showing the saved value while the monitor comes back at its own brightness
defaults write app.monitorcontrol.MonitorControl startupAction -int 1

# Prevent sleep when connected to power
sudo pmset -c displaysleep 0  # Never turn off display on charger
sudo pmset -c sleep 0         # Never sleep on charger

# Disable screen saver (lock screen still works)
defaults -currentHost write com.apple.screensaver idleTime -int 0

killall Finder
killall Dock
killall cfprefsd 2>/dev/null || true

echo ""
echo "Note: the following settings may need to be set manually:"
echo "  - Wallpaper rotation: System Settings > Wallpaper"
echo "  - Input source switching (Ctrl+Cmd+\`): System Settings > Keyboard > Keyboard Shortcuts > Input Sources"
