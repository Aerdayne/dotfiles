# Moonlander

The keyboard's firmware comes from two places, and nothing is set in both:

- [Oryx](https://configure.zsa.io/moonlander/layouts/oq3xD/latest) has the layout: keys, layers, layer colours, settings, and which built-in LED animations exist.
- `keymap/` has what Oryx can't do: the warm RGB effects and the lighting defaults. These files are added to Oryx's source, with `config.h` and `rules.mk` going at the end of Oryx's own.

`moonlander` builds the latest compiled Oryx revision plus that code with ZSA's QMK fork, and flashes it with zapp: press the reset key on the Media layer when it waits for the keyboard. After flashing it saves the layout to `~/.local/share/moonlander`, for the keyboard view of the shortcut overlay (see `configs/hammerspoon`). The build runs in a container with the same compiler Oryx uses, so the unmodified layout comes out byte for byte the same as Oryx's own firmware. After changing the layout, click Compile in Oryx and run `moonlander` rather than flashing from Oryx; flashing from Oryx, Keymapp or `zapp update` drops the custom effects, until `moonlander` puts them back.

```bash
moonlander --reset-lighting  # also put the lighting settings back to the defaults
moonlander --no-flash        # only build
zapp flash https://configure.zsa.io/moonlander/layouts/oq3xD/latest  # back to plain Oryx firmware
```

The keyboard saves the current effect as its position in the firmware's list of effects, so when that list changes, for example after ticking another animation in Oryx, the next flash starts on Molten gold rather than on whichever effect has taken that position. Brightness and speed are kept; `--reset-lighting` resets those too.

The script downloads the layout from Oryx without logging in, so the layout has to stay public.
