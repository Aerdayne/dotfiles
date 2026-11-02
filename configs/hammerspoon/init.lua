require("hs.ipc") -- lets the `hs` command line tool talk to Hammerspoon
hs.autoLaunch(true)

local shortcuts = require("shortcuts")
local hyper = { "cmd", "shift", "alt", "ctrl" }

-- Taken from https://github.com/pgilad/dotfiles/blob/master/hammerspoon/init.lua#L1
function openApp(name)
  local app = hs.application.find(name)

  -- VS Code is installed as "Visual Studio Code", but its running app is called "Code"
  if name == "Visual Studio Code" then
    app = hs.application.find("Code")
  end

  if app and app:isFrontmost() then
    app:hide()
    return
  end

  hs.application.launchOrFocus(name)
end

function mountApp(appName)
  return function()
      openApp(appName)
  end
end

hs.hotkey.bind(hyper, "r", function() hs.reload() end)
shortcuts.add("Hammerspoon", hyper, "r", "Reload Hammerspoon config")

-- Hyper + letter opens the app, or hides it when it's already in front
local launchers = {
  { "a", "Alacritty" },
  { "c", "Google Chrome" },
  { "v", "Visual Studio Code" },
  { "f", "Finder" },
  { "s", "Slack" },
  { "o", "Obsidian" },
}
for _, launcher in ipairs(launchers) do
  hs.hotkey.bind(hyper, launcher[1], mountApp(launcher[2]))
  shortcuts.add("Open or hide app", hyper, launcher[1], launcher[2])
end

-- Hyper + Space shows the keyboard shortcuts of the focused app (see shortcuts.lua). Space is under
-- the left thumb, so it pairs easily with a Hyper key on the right hand.
shortcuts.start(hyper, "space")
