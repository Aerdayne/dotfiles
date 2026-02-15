# Dotfiles

Personal dotfile setup for Apple Silicon Macbooks - opinionated and not guaranteed to work correctly.

## Setup

### 1. Disable SIP (required for yabai)

Before running the installer, partially disable SIP:

1. Shut down, hold power button until "Loading startup options" appears
2. Options > Utilities > Terminal
3. Run: `csrutil enable --without fs --without debug --without nvram`
4. Reboot
5. Run: `sudo nvram boot-args=-arm64e_preview_abi`
6. Reboot again

Verify with `csrutil status` - should show `NVRAM Protections: disabled`.

### 2. Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Aerdayne/dotfiles/master/bootstrap.sh)"
```

This installs Xcode CLT (if needed), clones the repo, and runs `./install`.

First run will prompt for Accessibility permissions for yabai and skhd - grant them in System Settings > Privacy & Security.

### 3. After yabai updates

The yabai sudoers entry contains a sha256 hash of the binary. After `brew upgrade yabai`, re-run:

```bash
./configs/yabai/setup-yabai-sudoers.sh
yabai --restart-service
```

### 4. Launch apps and accept prompts

Launch each app installed via Brew and other means. MacOS will prompt for permissions and provide instructions where necessary.

## Cheatsheet

```bash
code --list-extensions                      # dump VSCode extensions
csrutil status                              # check SIP status
brew bundle dump                            # dump Brewfile
brew bundle --file ./configs/brew/Brewfile  # install from Brewfile
```
