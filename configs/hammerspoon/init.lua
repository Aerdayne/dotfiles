-- Taken from https://github.com/pgilad/dotfiles/blob/master/hammerspoon/init.lua#L1
function openApp(name)
  app = hs.application.find(name)

  -- The dirtiest thing that I have written this week
  -- For some reason whenever VSCode is actually launched it
  -- should be referred to as 'Code'.
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

hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "r", function() hs.reload() end)

hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "a", mountApp("Alacritty"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "c", mountApp("Google Chrome"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "v", mountApp("Visual Studio Code"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "f", mountApp("Finder"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "s", mountApp("Slack"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "d", mountApp("Docker"))
hs.hotkey.bind({ "cmd", "shift", "alt", "ctrl" }, "o", mountApp("Obsidian"))
