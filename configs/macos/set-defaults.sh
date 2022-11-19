# !/usr/bin/env bash

set -e

osascript -e 'tell application "System Preferences" to quit'

osascript <<EOF
tell application "System Events"
    tell current desktop
        set pictures folder to "~/wallpapers"
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

defaults write com.apple.dashboard mcx-disabled -bool "true" # Disable dashboard
defaults write com.apple.menuextra.battery ShowPercent -bool "true" # Enable battery percentage
defaults write com.apple.menuextra.battery ShowTime -bool "false" # Disable battery time
defaults write com.apple.dock mru-spaces -bool false # Disable auto rearrangement of spaces based on recency of their usage
defaults write -g NSScrollViewRubberbanding -int 0 # Disable rubber scrolling
defaults write -g AppleFontSmoothing -int 0 # Alacritty changelog: "`font.use_thin_strokes` config field; to use thin strokes on macOS, set `AppleFontSmoothing` to 0"
defaults write -g com.apple.mouse.tapBehavior -int 0 # Trackpad tap to click
defaults write -g com.apple.trackpad.forceClick -int 1 # Trackpad force click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock -bool false # Dragging without drag lock
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
defaults write com.apple.dock "autohide" -bool "true" # Autohide Dock
defaults write com.apple.dock "autohide-time-modifier" -float 0 # Make Dock appear and disappear instantly
defaults write com.apple.dock "expose-animation-duration" -float 0.1 # Dock minimize animation
defaults write com.apple.dock "mineffect" -string "scale" # Mission Control animations speed up
defaults write com.apple.universalaccess "reduceMotion" -bool "true" # Make space swapping instant
defaults write com.apple.dock "show-recents" -bool "false" # Hide recents from Dock
defaults write com.apple.finder "QuitMenuItem" -bool "true" # Quit option in the Finder
defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true" # Show file extensions in the Finder
defaults write com.apple.finder "AppleShowAllFiles" -bool "true" # Show hidden files in the Finder
defaults write com.apple.finder "ShowPathbar" -bool "true" # Show path bar in the Finder
defaults write com.apple.finder "QuitMenuItem" -bool "true" # Enable quit button
defaults write com.apple.finder "CreateDesktop" -bool "false" # Hide all icons on desktop
defaults write com.apple.AppleMultitouchTrackpad "Dragging" -int 1 # Enable trackpad dragging
defaults write com.apple.Accessibility "KeyRepeatDelay" -float 0.25

killall Finder
killall Dock
