# Hammerspoon

## App launchers

Hyper and a letter opens an app, or hides it when it's already in front. Hyper is ⌃⌥⇧⌘, which is a single key on the Moonlander. The letters are in `init.lua`.

## Keyboard shortcut overlay

Hyper + Space, or the ⌘ icon in the menu bar, shows the keyboard shortcuts of the app in front: its menu shortcuts, the skhd and yabai bindings, tmux and Alacritty in the terminal, VS Code's keybindings, the launchers above and the common macOS shortcuts. Typing filters them: words search the descriptions, and modifier names with a key (`cmd w`, `shift cmd p`, or `⌘w`) find that exact shortcut. Tab switches between the list and the keyboard, and Escape closes it. ↑ and ↓ scroll, Page Up and Page Down go a screen at a time, and ⌘↑ and ⌘↓ (or Home and End) go to the top and bottom. tmux's built-in bindings stay folded into one row until it's clicked or a search finds them.

The keyboard view shows what each key does with the modifiers held down, or with the combination picked above the keyboard, and lights the modifier keys to press. Pointing at a key lists everything on it, and typing lights the keys that match. In a terminal, ⌃Z (tmux's prefix) shows what each key does after it, and ⌃Z again goes back. It draws the Moonlander while it's plugged in, with its layers, from the layout `moonlander` saves to `~/.local/share/moonlander` after flashing; otherwise it draws the built-in keyboard, labelled with what the keyboard layout types. Free keys marks the keys a combination doesn't use yet. On the keys, ! is a shortcut skhd or Hammerspoon takes from the app, × is two global shortcuts on one key, and • is an Option accent key (⌥E for é, ⌥U for ü) that a shortcut has taken.

The shortcuts are read from wherever they're defined, so the overlay doesn't need updating when a binding changes:

- Menu shortcuts come from the app through the Accessibility API, which is why Hammerspoon needs Accessibility access. Hammerspoon's own menu reader takes seconds for a browser's history and bookmarks menus, so `menu-shortcuts.swift` reads only what a shortcut needs. Hammerspoon compiles it into `~/.hammerspoon/build` the first time it loads, and again whenever the source changes.
- skhd and tmux bindings are labelled by the comment above them in `.skhdrc` and `.tmux.conf`. In `.skhdrc`, the part before the colon is the group, so "Windows: Move left" shows "Move left" under Windows.
- System shortcuts changed in System Settings > Keyboard > Keyboard Shortcuts are read from its preferences.

Shortcuts that aren't in any menu, such as a web app's own or VS Code commands that are only in the command palette, can't be found this way.
