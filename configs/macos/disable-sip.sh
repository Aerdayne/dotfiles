# !/usr/bin/env bash

# WARNING: This script should be run while in the Recovery Mode.
# To run it, open Utilities/Terminal while in recovery mode:
# cd /Volumes/<drive name> && sh /Volumes/<drive name>/Users/<username>/dotfiles/configs/macos/disable-sip.sh

# Disabling SIP is required for yabai.
# https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection
# Note that this command is specific to my current MacOS, which is Mojave 10.14.6

csrutil enable --without debug --without fs
