# Dotfiles

1. `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Aerdayne/dotfiles/master/install.sh)"`
2. Run `./install`
3. To enable all features of `yabai` SIP should be disabled.

   Restart MacOS in the recovery mode and execute the contents of `configs/macos/disable-sip.sh`.

   This will disable SIP and enable certain features of yabai.

   After disabling SIP, restart again and run `sudo yabai --install-sa`.

## Notes to future self

- Dump current VSCode extensions

  `code --list-extensions`

- Check SIP status

  `csrutil status`

- Dump Brewfile

  `brew bundle dump`

---

## TODO

- A VPN toggle keybind & menu bar icon
- Ubersicht & simple-bar
- Google calendar integration
- Finer tmux configuration
