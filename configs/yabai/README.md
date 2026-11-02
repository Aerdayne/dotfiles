# yabai

skhd's bindings in `configs/skhd/.skhdrc` drive yabai. Most of them, such as creating, focusing and destroying spaces or sending a window to another one, go through yabai's scripting addition, which is why the installer needs SIP partly disabled.

## After yabai updates

`.yabairc` loads the scripting addition with `sudo`, which can't ask for a password when yabai starts at login. A sudoers entry allows that one command without a password, but only for the binary whose SHA-256 hash it names, so every update leaves it outdated, and `.yabairc` shows a notification instead of loading the addition. Renew the entry and restart yabai:

```bash
./configs/yabai/setup-yabai-sudoers.sh
yabai --restart-service
```

If yabai doesn't come back (`could not access accessibility features` in `/tmp/yabai_$USER.err.log`), macOS doesn't trust the new binary yet: turn on its new entry in System Settings > Privacy & Security > Accessibility, then run `yabai --start-service`.

## Helper scripts

yabai runs most of these on its signals (see `.yabairc`), and each script starts with a fuller explanation.

- `refresh-moved-spaces.sh`: yabai doesn't recompute the layout of a space that's dragged to another display in Mission Control, so the next time the space is shown its windows snap back to the old display's coordinates. While Mission Control is open, this refreshes the layout of any space whose display changed.
- `sync-true-tone.js`: True Tone tints every connected display and macOS has no per-display switch, so this keeps it on only while the MacBook is used without an external one.
- `fix-notch-shield.sh` and `recreate-space.sh`: macOS sometimes leaves a black bar stuck behind the menu bar on the MacBook screen, and only destroying that desktop removes it. When that happens, the desktop is replaced with a fresh one holding the same windows. `top-windows.swift` lists the windows along the top of each display, which is how the bar was identified.
- `focus-adjacent-space.sh`: yabai's previous and next space follow macOS's list of displays rather than where the displays are, so skhd's ⌃← and ⌃→ use this instead, which goes left to right across them.
