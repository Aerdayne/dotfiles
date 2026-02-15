#!/usr/bin/env bash
set -e

# Install Xcode Command Line Tools silently if not present
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    softwareupdate -i "$(softwareupdate -l | grep -o '.*Command Line Tools.*' | head -1 | sed 's/^[* ]*//')" --agree-to-license
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi

DOTFILES_DIR="$HOME/dotfiles"

if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "Dotfiles already cloned, pulling latest..."
    git -C "$DOTFILES_DIR" pull
    git -C "$DOTFILES_DIR" submodule update --init --recursive
else
    echo "Cloning dotfiles..."
    git clone --recursive https://github.com/Aerdayne/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
./install
