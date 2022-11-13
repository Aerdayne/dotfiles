# !/usr/bin/env bash

# WARNING: This script should be run while in the Recovery Mode.
# To run it, open Utilities/Terminal while in recovery mode:
# cd /Volumes/<drive name> && sh /Volumes/<drive name>/Users/<username>/dotfiles/configs/macos/disable-sip.sh

# Disabling SIP is required for yabai.
# https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection
# The command below is for Apple Silicon.

csrutil disable --with kext --with dtrace --with basesystem
