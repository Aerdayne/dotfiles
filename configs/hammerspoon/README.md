# Hammerspoon

## App launchers

Hyper and a letter opens an app, or hides it when it's already in front. Hyper is ⌃⌥⇧⌘, which is a single key on the Moonlander. The letters are in `init.lua`.

## Keyboard shortcut overlay

Hyper + Space, or the ⌘ icon in the menu bar, shows the keyboard shortcuts of the app in front: its menu shortcuts, the skhd and yabai bindings, tmux and Alacritty in the terminal, VS Code's keybindings, the launchers above and the common macOS shortcuts. Typing filters them, Tab shows tmux's built-in bindings, and Escape closes it.

The shortcuts are read from wherever they're defined, so the overlay doesn't need updating when a binding changes:

- Menu shortcuts come from the app through the Accessibility API, which is why Hammerspoon needs Accessibility access. Hammerspoon's own menu reader takes seconds for a browser's history and bookmarks menus, so `menu-shortcuts.swift` reads only what a shortcut needs. Hammerspoon compiles it into `~/.hammerspoon/build` the first time it loads, and again whenever the source changes.
- skhd and tmux bindings are labelled by the comment above them in `.skhdrc` and `.tmux.conf`. In `.skhdrc`, the part before the colon is the group, so "Windows: Move left" shows "Move left" under Windows.
- System shortcuts changed in System Settings > Keyboard > Keyboard Shortcuts are read from its preferences.

Shortcuts that aren't in any menu, such as a web app's own or VS Code commands that are only in the command palette, can't be found this way.
