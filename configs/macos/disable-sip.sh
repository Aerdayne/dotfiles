#!/usr/bin/env bash

# Disabling SIP is required for yabai's scripting addition.
# https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection
#
# This must be run in Recovery Mode (Apple Silicon):
#   1. Shut down, hold power button until "Loading startup options" appears
#   2. Options > Utilities > Terminal
#   3. csrutil enable --without fs --without debug --without nvram
#   4. Reboot
#   5. sudo nvram boot-args=-arm64e_preview_abi
#   6. Reboot again

csrutil enable --without fs --without debug --without nvram
