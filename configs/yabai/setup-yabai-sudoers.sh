#!/usr/bin/env bash

# Allows yabai to load its scripting addition without a password prompt.
# Must be re-run whenever the yabai binary is updated (the sha256 hash changes).
# https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)#configure-scripting-addition

set -e

# Use the path .yabairc runs (the Homebrew symlink), not its realpath: sudo matches the path as
# invoked and doesn't resolve symlinks, so a rule for the Cellar path never matches `sudo yabai`
YABAI_BIN=$(command -v yabai)
YABAI_HASH=$(shasum -a 256 "$YABAI_BIN" | cut -d " " -f 1)
SUDOERS_LINE="$(whoami) ALL=(root) NOPASSWD: sha256:${YABAI_HASH} ${YABAI_BIN} --load-sa"
SUDOERS_FILE="/private/etc/sudoers.d/yabai"

echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 0440 "$SUDOERS_FILE"

# Validate the sudoers file
if sudo visudo -c -f "$SUDOERS_FILE" > /dev/null 2>&1; then
    echo "yabai sudoers entry installed successfully"
else
    echo "Error: sudoers file is invalid, removing it"
    sudo rm "$SUDOERS_FILE"
    exit 1
fi
