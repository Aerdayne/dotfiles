# Dotfiles

MacOS setup for Apple Silicon MacBooks: fish, tmux and Alacritty in the terminal, yabai and skhd to tile windows, Hammerspoon for app shortcuts, and the firmware for a ZSA Moonlander keyboard. It's opinionated and not guaranteed to work on other machines.

## Installing

yabai needs System Integrity Protection partly disabled to load its scripting addition, which is what lets it create, focus and move spaces and send windows between them. That's only possible from Recovery, so it has to be done before the installer runs ([yabai's wiki](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection) has the details):

1. Shut down, then hold the power button until "Loading startup options" appears.
2. Choose Options, then Utilities > Terminal.
3. Run `csrutil enable --without fs --without debug --without nvram` and restart.
4. Run `sudo nvram boot-args=-arm64e_preview_abi` and restart again.

`csrutil status` should now report `NVRAM Protections: disabled`. Then install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Aerdayne/dotfiles/master/bootstrap.sh)"
```

This installs the Xcode command line tools if they're missing, clones the repository to `~/dotfiles` and runs `./install`. On the first run, macOS asks to give yabai, skhd and Hammerspoon Accessibility access in System Settings > Privacy & Security; other apps ask for their permissions the first time they're opened.

## How it's organised

`./install` runs [dotbot](https://github.com/anishathalye/dotbot) with the files in `workflows/`, in order: Homebrew with the Brewfile and the macOS defaults, then the shell, then the configs, and last the services that start at login. Each step checks what's already done, so the installer can be run again after any change: it adds new links and missing packages and leaves the rest alone.

The configs are symlinked into place from `configs/`, one folder per tool, so editing `~/.tmux.conf` edits this repository. Most of them only need their comments; these have a README:

- [Git](configs/git/README.md): which GitHub account a repository uses, for git and gh
- [yabai](configs/yabai/README.md): window management, its helper scripts, and what to do after it updates
- [Hammerspoon](configs/hammerspoon/README.md): app launchers and the keyboard shortcut overlay
- [Moonlander](configs/moonlander/README.md): building and flashing the keyboard's firmware
