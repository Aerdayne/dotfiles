-- Keyboard shortcut overlay: shows the shortcuts available in the focused app.
-- It combines the app's own menu shortcuts (read through the Accessibility API), skhd and yabai,
-- tmux and Alacritty in the terminal, your VS Code keybindings, the Hammerspoon bindings in
-- init.lua and the common macOS shortcuts. Shortcuts that aren't in any menu, such as a web app's
-- inside the browser or VS Code commands only in the command palette, can't be found this way.
--
-- Menus are read by menu-shortcuts.swift (compiled on first load) when Hammerspoon starts and when
-- an app is activated, and kept in memory, so the overlay opens from the cache; a later read only
-- refreshes it. Nothing is written to disk except the compiled reader and its icon.

local M = {}

local HOME = os.getenv("HOME")
local TMUX = "/opt/homebrew/bin/tmux"
local TERMINALS = { ["org.alacritty"] = true, ["com.apple.Terminal"] = true }
local BUILD = HOME .. "/.hammerspoon/build"
local READER_SOURCE = HOME .. "/.hammerspoon/menu-shortcuts.swift"
local READER = BUILD .. "/menu-shortcuts"
local ICON = BUILD .. "/icon.png"
local MENU_REFRESH_SECONDS = 600

-- Key names --------------------------------------------------------------------------------------

local MOD_SYMBOLS = { fn = "fn ", ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" }
local MOD_ORDER = { "fn", "ctrl", "alt", "shift", "cmd" }
local MOD_ALIASES = { control = "ctrl", option = "alt", opt = "alt", command = "cmd" }
local KEY_NAMES = {
    left = "←", right = "→", up = "↑", down = "↓", space = "Space", tab = "⇥",
    ["return"] = "↩", enter = "↩", escape = "⎋", esc = "⎋",
    delete = "⌫", backspace = "⌫", bspace = "⌫", forwarddelete = "⌦", dc = "⌦",
    home = "↖", ["end"] = "↘", pageup = "⇞", pagedown = "⇟", ppage = "⇞", npage = "⇟",
}

-- Formats a key combination the way macOS menus do, e.g. ({ "shift", "cmd" }, "p") -> "⇧⌘P"
local function combo(mods, key)
    local set = {}
    for _, mod in ipairs(mods or {}) do
        mod = mod:lower()
        mod = MOD_ALIASES[mod] or mod
        if mod:match("^[lr]%a+$") and MOD_SYMBOLS[mod:sub(2)] then mod = mod:sub(2) end -- skhd's lcmd, ralt…
        if mod == "hyper" or mod == "meh" then
            set.ctrl, set.alt, set.shift = true, true, true
            set.cmd = set.cmd or mod == "hyper"
        else
            set[mod] = true
        end
    end
    local name = KEY_NAMES[key:lower()] or (key:match("^[fF]%d+$") and key:upper()) or (#key == 1 and key:upper()) or key
    if set.ctrl and set.alt and set.shift and set.cmd then
        return (set.fn and "fn " or "") .. "Hyper " .. name
    end
    local text = ""
    for _, mod in ipairs(MOD_ORDER) do
        if set[mod] then text = text .. MOD_SYMBOLS[mod] end
    end
    return text .. name
end

local function humanize(name)
    local words = (name:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"))
    words = words:lower()
    return words:sub(1, 1):upper() .. words:sub(2)
end

local function readLines(path)
    local file = io.open(path)
    if not file then return {} end
    local lines = {}
    for line in file:lines() do table.insert(lines, line) end
    file:close()
    return lines
end

-- The focused app's menus ------------------------------------------------------------------------

-- Menus give special keys as control characters, or as the private-use characters AppKit uses for
-- arrows and function keys (NSUpArrowFunctionKey is U+F700, NSF1FunctionKey U+F704…)
local CONTROL_KEYS = { ["\t"] = "⇥", ["\b"] = "⌫", ["\127"] = "⌫", ["\r"] = "↩", ["\3"] = "⌤", ["\27"] = "⎋", [" "] = "Space" }
local FUNCTION_KEYS = {
    [0xF700] = "↑", [0xF701] = "↓", [0xF702] = "←", [0xF703] = "→", [0xF728] = "⌦",
    [0xF729] = "↖", [0xF72B] = "↘", [0xF72C] = "⇞", [0xF72D] = "⇟",
}
for n = 1, 35 do FUNCTION_KEYS[0xF703 + n] = "F" .. n end
-- kMenu*Glyph values, for the rare item with a glyph but no character
local GLYPHS = { [2] = "⇥", [11] = "↩", [23] = "⌫", [27] = "⎋", [100] = "←", [101] = "→", [104] = "↑", [106] = "↓" }

local function menuKey(char, glyph)
    char = char or ""
    if char == "" then return GLYPHS[glyph] end
    if CONTROL_KEYS[char] then return CONTROL_KEYS[char] end
    local code = utf8.len(char) == 1 and utf8.codepoint(char)
    return FUNCTION_KEYS[code] or char
end

-- The reader passes the raw Accessibility bitmask, Hammerspoon's getMenuItems a list of names
local function menuMods(value)
    if type(value) == "table" then return value end
    value = math.tointeger(value) or 0
    local mods = {}
    if value & 8 == 0 then table.insert(mods, "cmd") end
    if value & 1 ~= 0 then table.insert(mods, "shift") end
    if value & 2 ~= 0 then table.insert(mods, "alt") end
    if value & 4 ~= 0 then table.insert(mods, "ctrl") end
    return mods
end

-- Groups the shortcuts by menu (the app menu, File, Edit…). The Apple menu's are in the macOS section.
local function menuGroups(shortcuts)
    local groups, byMenu, seen = {}, {}, {}
    for _, shortcut in ipairs(shortcuts) do
        local key = menuKey(shortcut.char, shortcut.glyph)
        if key and shortcut.menu ~= "Apple" then
            local mods = menuMods(shortcut.modifiers)
            -- The Globe/fn key isn't reported; a letter without modifiers is a Globe shortcut (fn E)
            if #mods == 0 and key:match("^%w$") then mods = { "fn" } end
            local keys = combo(mods, key)
            local label = #shortcut.path > 0 and table.concat(shortcut.path, " › ") .. " › " .. shortcut.title or shortcut.title
            if not seen[shortcut.menu .. keys .. label] then
                seen[shortcut.menu .. keys .. label] = true
                local group = byMenu[shortcut.menu]
                if not group then
                    group = { title = shortcut.menu, rows = {} }
                    byMenu[shortcut.menu] = group
                    table.insert(groups, group)
                end
                table.insert(group.rows, { keys = { keys }, label = label })
            end
        end
    end
    return groups
end

-- Flattens Hammerspoon's getMenuItems tree into the reader's format, for when the reader isn't built
local function flattenMenu(menu)
    local shortcuts = {}
    for _, top in ipairs(menu or {}) do
        local function walk(items, path)
            for _, item in ipairs(items or {}) do
                local title = item.AXTitle or ""
                if title ~= "" then
                    table.insert(shortcuts, {
                        menu = top.AXTitle, path = path, title = title, char = item.AXMenuItemCmdChar,
                        glyph = item.AXMenuItemCmdGlyph, modifiers = item.AXMenuItemCmdModifiers,
                    })
                    local children = item.AXChildren and item.AXChildren[1]
                    if children then
                        local subpath = { table.unpack(path) }
                        table.insert(subpath, title)
                        walk(children, subpath)
                    end
                end
            end
        end
        walk(top.AXChildren and top.AXChildren[1], {})
    end
    return shortcuts
end

local menuCache = {} -- by bundle ID: { version, time, groups }
local readerReady = false
local waiting, tasks = {}, {} -- callbacks waiting for a read under way, and the running reads

local function cacheKey(app)
    return app:bundleID() or app:name()
end

local function appVersion(app)
    local info = app:bundleID() and hs.application.infoForBundleID(app:bundleID())
    return info and info.CFBundleShortVersionString or ""
end

-- Menus are read again after ten minutes (shortcuts changed in the app or System Settings), or
-- when the app was updated
local function isFresh(app)
    local entry = menuCache[cacheKey(app)]
    return entry ~= nil and entry.version == appVersion(app) and os.time() - entry.time < MENU_REFRESH_SECONDS
end

-- Reads an app's menus into the cache, then calls callback (also when a read was already under way)
local function readMenus(app, callback)
    local key = cacheKey(app)
    if waiting[key] then
        if callback then table.insert(waiting[key], callback) end
        return
    end
    waiting[key] = { callback }
    local function finish(shortcuts)
        if shortcuts then
            menuCache[key] = { version = appVersion(app), time = os.time(), groups = menuGroups(shortcuts) }
        end
        local callbacks = waiting[key]
        waiting[key], tasks[key] = nil, nil
        for _, fn in ipairs(callbacks) do fn() end
    end
    local function fallback()
        app:getMenuItems(function(menu) finish(menu and flattenMenu(menu)) end)
    end
    if not readerReady then return fallback() end
    tasks[key] = hs.task.new(READER, function(code, output)
        local ok, shortcuts = pcall(hs.json.decode, output)
        if code == 0 and ok and shortcuts then finish(shortcuts) else fallback() end
    end, { tostring(app:pid()) })
    tasks[key]:start()
end

-- Reads the menus of the running apps that aren't cached yet, one app at a time
local function prewarm()
    local queue = {}
    for _, app in ipairs(hs.application.runningApplications()) do
        if app:kind() == 1 and app:bundleID() ~= hs.processInfo.bundleID and not isFresh(app) then table.insert(queue, app) end
    end
    local function nextApp()
        local app = table.remove(queue, 1)
        if app then readMenus(app, nextApp) end
    end
    nextApp()
end

-- Compiles the reader when it's missing or older than its source (after a pull)
local function buildReader(callback)
    local source, reader = hs.fs.attributes(READER_SOURCE), hs.fs.attributes(READER)
    if not source then return end
    if reader and reader.modification >= source.modification then return callback() end
    hs.fs.mkdir(BUILD)
    M.buildTask = hs.task.new("/usr/bin/swiftc", function(code, _, errors)
        if code ~= 0 then return print("shortcuts: couldn't build the menu reader, using getMenuItems:\n" .. errors) end
        os.remove(ICON) -- render the icon again with the new build
        callback()
    end, { "-O", "-o", READER, READER_SOURCE })
    M.buildTask:start()
end

-- The ⌘ SF Symbol, rendered by the reader at the size of the other menu bar icons
local function setIcon()
    local function apply()
        local image = hs.image.imageFromPath(ICON)
        if image then M.menubar:setIcon(image, true):setTitle(nil) end
    end
    if hs.fs.attributes(ICON) then return apply() end
    M.iconTask = hs.task.new(READER, function(code)
        if code == 0 then apply() end
    end, { "icon", "command", ICON })
    M.iconTask:start()
end

-- skhd and yabai ---------------------------------------------------------------------------------

local SKHD_MODS = { cmd = true, alt = true, shift = true, ctrl = true, fn = true, hyper = true, meh = true }
for _, mod in ipairs({ "cmd", "alt", "shift", "ctrl" }) do SKHD_MODS["l" .. mod], SKHD_MODS["r" .. mod] = true, true end

-- Reads ~/.skhdrc. A binding's description is the "# Category: Description" comment above it, which
-- also covers the bindings below it up to the next blank line (alt - 1…9 share one comment).
local function parseSkhd()
    local bindings, blacklist = {}, {}
    local comment, block, inBlacklist, continued
    for _, line in ipairs(readLines(HOME .. "/.skhdrc")) do
        local text = line:match("^%s*(.-)%s*$")
        if continued then
            continued = text:sub(-1) == "\\"
        elseif inBlacklist then
            local name = text:match('^"(.-)"$')
            if name then blacklist[name:lower()] = true end
            inBlacklist = text ~= "]"
        elseif block then
            local target, command = text:match("^(%S+)%s*:%s*(.*)$")
            if target then block.targets[(target:gsub('"', "")):lower()] = command end
            if text == "]" then block = nil end
        elseif text == "" then
            comment = nil
        elseif text:match("^%.blacklist") then
            inBlacklist = true
        elseif text:sub(1, 1) == "#" then
            if not text:match("^#!") then comment = text:match("^#%s*(.-)$") end
        else
            local modText, key, rest = text:match("^([%a%s%+]-)%s*%-%s*(%S+)%s*(.*)$")
            local mods, valid = {}, modText ~= nil
            for mod in (modText or ""):gmatch("%a+") do
                valid = valid and SKHD_MODS[mod] ~= nil
                table.insert(mods, mod)
            end
            if valid and comment then
                local binding = { mods = mods, key = key, comment = comment, command = rest:match("^:%s*(.*)$") or "" }
                if rest == "[" then
                    binding.targets = {}
                    block = binding
                end
                table.insert(bindings, binding)
            end
            continued = text:sub(-1) == "\\"
        end
    end
    return bindings, blacklist
end

-- Bindings in an app block ([ "Alacritty" : … ; * : … ]) apply only to the apps they name, or
-- to every app when there's a * entry; "~" passes the key through to the app
local function skhdApplies(binding, appName)
    if not binding.targets then return true end
    local command = binding.targets[appName]
    if command then return command ~= "~" end
    return binding.targets["*"] ~= nil
end

local function skhdGroups(appName)
    local bindings, blacklist = parseSkhd()
    if blacklist[appName] then return nil end
    local groups, byCategory = {}, {}
    local i = 1
    while i <= #bindings do
        local run = { bindings[i] }
        while bindings[i + #run] and bindings[i + #run].comment == bindings[i].comment do
            table.insert(run, bindings[i + #run])
        end
        i = i + #run

        local applying = {}
        for _, binding in ipairs(run) do
            if skhdApplies(binding, appName) then table.insert(applying, binding) end
        end
        if #applying > 0 then
            local category, description = applying[1].comment:match("^(.-):%s*(.+)$")
            if not category then category, description = "Other", applying[1].comment end
            local group = byCategory[category]
            if not group then
                group = { title = category, rows = {} }
                byCategory[category] = group
                table.insert(groups, group)
            end
            local first, last = applying[1], applying[#applying]
            if #applying > 1 and first.key:match("^%d$") and last.key:match("^%d$") then
                table.insert(group.rows, { keys = { combo(first.mods, first.key .. "–" .. last.key) }, label = description })
            else
                for _, binding in ipairs(applying) do
                    -- Several keys under one comment differ by their command's last word (bsp, float, stack)
                    local label = #applying > 1 and description .. " (" .. (binding.command:match("([%w%-]+)%s*$") or "") .. ")" or description
                    table.insert(group.rows, { keys = { combo(binding.mods, binding.key) }, label = label })
                end
            end
        end
    end
    return groups
end

local function yabaiMouse()
    local config = {}
    for _, line in ipairs(readLines(HOME .. "/.yabairc")) do
        local name, value = line:match("^%s*yabai %-m config%s+(mouse_%S+)%s+(%S+)")
        if name then config[name] = value end
    end
    local mod = config.mouse_modifier
    if not mod then return {} end
    local actions = { move = "Move window", resize = "Resize window" }
    local rows = {}
    if actions[config.mouse_action1] then
        local label = actions[config.mouse_action1]
        if config.mouse_drop_action == "swap" and config.mouse_action1 == "move" then label = label .. ", drop on another to swap" end
        table.insert(rows, { keys = { combo({ mod }, "Drag") }, label = label })
    end
    if actions[config.mouse_action2] then
        table.insert(rows, { keys = { combo({ mod }, "Right-drag") }, label = actions[config.mouse_action2] })
    end
    return rows
end

-- tmux -------------------------------------------------------------------------------------------

-- "C-z" -> "⌃Z", "M-x" -> "⌥X", "H" -> "⇧H"
local function tmuxKey(key)
    local mods = {}
    while true do
        local mod, rest = key:match("^([CMS])%-(.+)$")
        if not mod then break end
        table.insert(mods, ({ C = "ctrl", M = "alt", S = "shift" })[mod])
        key = rest
    end
    key = (key:gsub("^'(.+)'$", "%1"):gsub('^"(.+)"$', "%1"))
    if key:match("^%u$") then table.insert(mods, "shift") end
    return combo(mods, key)
end

-- Your bindings from ~/.tmux.conf, described by the comment line above each
local function tmuxConfig()
    local prefix, comment = "C-b", nil
    local tables = { prefix = {}, root = {}, copy = {} }
    local custom = {}
    for _, line in ipairs(readLines(HOME .. "/.tmux.conf")) do
        local text = line:match("^%s*(.-)%s*$")
        prefix = text:match("^set%-option%s+%-g%s+prefix%s+(%S+)") or text:match("^set%s+%-g%s+prefix%s+(%S+)") or prefix
        if text:match("^#[^#!]") then
            comment = text:match("^#%s*(.-)$")
        elseif text:match("^bind") then
            local args = {}
            for word in text:gmatch("%S+") do table.insert(args, word) end
            local keyTable, i = "prefix", 2
            while args[i] and args[i]:sub(1, 1) == "-" do
                if args[i]:find("n") then keyTable = "root" end
                if args[i] == "-T" then
                    i = i + 1
                    keyTable = args[i] == "root" and "root" or (args[i]:match("^copy") and "copy") or args[i]
                end
                i = i + 1
            end
            local key = args[i]
            if keyTable == "prefix" and key then custom[(key:gsub("^'(.+)'$", "%1"))] = true end
            if comment and key and tables[keyTable] then
                table.insert(tables[keyTable], { keys = { tmuxKey(key) }, label = comment })
            end
            comment = nil
        elseif not text:match("^unbind") then
            comment = nil -- a comment above an unbind still describes the bind that follows it
        end
    end
    return prefix, tables, custom
end

-- tmux's own bindings that are still in place, with tmux's descriptions
local function tmuxDefaults(prefix, custom)
    local output, ok = hs.execute(TMUX .. " list-keys -N 2>/dev/null")
    local rows = {}
    if not ok then return rows end
    for line in output:gmatch("[^\n]+") do
        local first, key, note = line:match("^(%S+)%s+(%S+)%s+(.+)$")
        if first == prefix and not custom[key] then
            table.insert(rows, { keys = { tmuxKey(key) }, label = note })
        end
    end
    return rows
end

-- "Select window 0" … "Select window 9", on keys 0…9, become one "Select window 0–9" row
local function collapseDigits(rows)
    local collapsed, i = {}, 1
    while i <= #rows do
        local stem, digit = rows[i].label:match("^(.-) (%d)$")
        local last = i
        while stem and rows[i].keys[1] == digit and rows[last + 1]
            and rows[last + 1].label == stem .. " " .. (tonumber(digit) + last + 1 - i)
            and rows[last + 1].keys[1] == tostring(tonumber(digit) + last + 1 - i) do
            last = last + 1
        end
        if last > i then
            local range = digit .. "–" .. (tonumber(digit) + last - i)
            table.insert(collapsed, { label = stem .. " " .. range, keys = { range } })
        else
            table.insert(collapsed, rows[i])
        end
        i = last + 1
    end
    return collapsed
end

local function tmuxGroups()
    local prefix, tables, custom = tmuxConfig()
    local after = "After " .. tmuxKey(prefix)
    return {
        { title = after, rows = tables.prefix },
        { title = "No prefix", rows = tables.root },
        { title = "Copy mode", rows = tables.copy },
        -- Folded to one row until you press Tab or search, as it's longer than everything else together
        { title = after .. " (built in)", rows = collapseDigits(tmuxDefaults(prefix, custom)), folded = true },
    }
end

-- Alacritty and VS Code config -------------------------------------------------------------------

-- Escape sequences Alacritty sends for its bindings, by what they do in the shell
local ALACRITTY_CHARS = {
    ["\\u001BOH"] = "Go to start of line", ["\\u001B[H"] = "Go to start of line",
    ["\\u001BOF"] = "Go to end of line", ["\\u001B[F"] = "Go to end of line",
    ["\\u001Bb"] = "Move back a word", ["\\u001Bf"] = "Move forward a word",
}

local function alacrittyRows()
    local rows, seen, entry = {}, {}, nil
    local function finish()
        if not entry or not entry.key then return end
        local label = entry.chars and ALACRITTY_CHARS[entry.chars] or (entry.action and entry.action ~= "None" and humanize(entry.action))
        if not label then return end
        local mods = {}
        for mod in (entry.mods or ""):gmatch("%a+") do table.insert(mods, mod) end
        local keys = combo(mods, entry.key)
        if not seen[keys .. label] then
            seen[keys .. label] = true
            table.insert(rows, { keys = { keys }, label = label })
        end
    end
    for _, line in ipairs(readLines(HOME .. "/.config/alacritty/alacritty.toml")) do
        if line:match("^%s*%[%[keyboard%.bindings%]%]") then
            finish()
            entry = {}
        elseif line:match("^%s*%[") then
            finish()
            entry = nil
        elseif entry then
            local name, value = line:match('^%s*(%w+)%s*=%s*"(.*)"%s*$')
            if name then entry[name] = value end
        end
    end
    finish()
    return rows
end

-- "workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup" -> "Quick open previous recently used editor in group"
local function vscodeCommand(command)
    command = command:gsub("^workbench%.action%.", ""):gsub("^editor%.action%.", "")
    local parts = {}
    for part in command:gmatch("[^%.]+") do table.insert(parts, humanize(part)) end
    return table.concat(parts, ": ")
end

local function vscodeRows()
    local file = io.open(HOME .. "/Library/Application Support/Code/User/keybindings.json")
    if not file then return {} end
    local text = file:read("a")
    file:close()
    -- The file is JSON with comments and trailing commas
    text = text:gsub("\n%s*//[^\n]*", "\n"):gsub("^%s*//[^\n]*", ""):gsub(",(%s*[%]}])", "%1")
    local ok, entries = pcall(hs.json.decode, text)
    local rows = {}
    for _, entry in ipairs(ok and entries or {}) do
        if entry.key and entry.command and entry.command:sub(1, 1) ~= "-" then
            local keys = {}
            for chord in entry.key:gmatch("%S+") do
                local parts = {}
                for part in chord:gmatch("[^+]+") do table.insert(parts, part) end
                local key = table.remove(parts)
                table.insert(keys, combo(parts, key))
            end
            table.insert(rows, { keys = { keys }, label = vscodeCommand(entry.command) }) -- one chord: ⌘K, then ⌘I
        end
    end
    return rows
end

-- macOS ------------------------------------------------------------------------------------------

-- Common system shortcuts by their com.apple.symbolichotkeys ID, with macOS's default keys. Changes
-- made in System Settings > Keyboard > Keyboard Shortcuts are read from its preferences file.
local SYSTEM_SHORTCUTS = {
    { id = 64, label = "Spotlight", mods = { "cmd" }, key = "space" },
    { id = 65, label = "Finder search window", mods = { "alt", "cmd" }, key = "space" },
    { id = 27, label = "Next window of the app", mods = { "cmd" }, key = "`" },
    { id = 98, label = "Search the app's menus", mods = { "shift", "cmd" }, key = "/" },
    { id = 28, label = "Screenshot of the screen", mods = { "shift", "cmd" }, key = "3" },
    { id = 29, label = "Screenshot of the screen to the clipboard", mods = { "ctrl", "shift", "cmd" }, key = "3" },
    { id = 30, label = "Screenshot of an area", mods = { "shift", "cmd" }, key = "4" },
    { id = 31, label = "Screenshot of an area to the clipboard", mods = { "ctrl", "shift", "cmd" }, key = "4" },
    { id = 184, label = "Screenshot and recording options", mods = { "shift", "cmd" }, key = "5" },
    { id = 32, label = "Mission Control", mods = { "ctrl" }, key = "up" },
    { id = 33, label = "App windows", mods = { "ctrl" }, key = "down" },
    { id = 79, label = "Move left a space", mods = { "ctrl" }, key = "left" },
    { id = 81, label = "Move right a space", mods = { "ctrl" }, key = "right" },
    { id = 60, label = "Previous input source", mods = { "ctrl" }, key = "space" },
    { id = 61, label = "Next input source", mods = { "ctrl", "alt" }, key = "space" },
    { id = 52, label = "Hide or show the Dock", mods = { "alt", "cmd" }, key = "d" },
}

local function storedCombo(parameters)
    local ascii, keycode, flags = table.unpack(parameters)
    flags = math.tointeger(flags) or 0
    local mods = {}
    if flags & 0x40000 ~= 0 then table.insert(mods, "ctrl") end
    if flags & 0x80000 ~= 0 then table.insert(mods, "alt") end
    if flags & 0x20000 ~= 0 then table.insert(mods, "shift") end
    if flags & 0x100000 ~= 0 then table.insert(mods, "cmd") end
    local key = hs.keycodes.map[math.tointeger(keycode)] or (ascii ~= 65535 and utf8.char(ascii)) or "?"
    return combo(mods, key)
end

local function systemRows()
    local preferences = hs.plist.read(HOME .. "/Library/Preferences/com.apple.symbolichotkeys.plist") or {}
    local stored = preferences.AppleSymbolicHotKeys or {}
    local rows = {
        { keys = { combo({ "cmd" }, "tab") }, label = "Switch apps" },
        { keys = { combo({ "alt", "cmd" }, "escape") }, label = "Force quit apps" },
        { keys = { combo({ "ctrl", "cmd" }, "q") }, label = "Lock screen" },
        { keys = { combo({ "shift", "cmd" }, "q") }, label = "Log out" },
    }
    for _, shortcut in ipairs(SYSTEM_SHORTCUTS) do
        local entry = stored[tostring(shortcut.id)]
        local keys = combo(shortcut.mods, shortcut.key)
        local enabled = true
        if entry then
            enabled = entry.enabled == true or entry.enabled == 1
            local parameters = entry.value and entry.value.parameters
            if parameters and parameters[2] and parameters[2] ~= 65535 then keys = storedCombo(parameters) end
        end
        if enabled then table.insert(rows, { keys = { keys }, label = shortcut.label }) end
    end
    return rows
end

-- Hammerspoon bindings registered by init.lua ----------------------------------------------------

local registered = {}

function M.add(groupTitle, mods, key, label)
    local group
    for _, existing in ipairs(registered) do
        if existing.title == groupTitle then group = existing end
    end
    if not group then
        group = { title = groupTitle, rows = {} }
        table.insert(registered, group)
    end
    table.insert(group.rows, { keys = { combo(mods, key) }, label = label })
end

-- Overlay ----------------------------------------------------------------------------------------

-- One row per action: "Paste and Match Style" with ⇧⌘V and ⌥⇧⌘V becomes one row with both keys.
-- Each entry in row.keys is an alternative; a list is a chord pressed in sequence (⌘K, then ⌘I).
local function mergeRows(rows)
    local merged, byLabel = {}, {}
    for _, row in ipairs(rows) do
        local target = byLabel[row.label]
        if not target then
            target = { label = row.label, keys = {}, seen = {} }
            byLabel[row.label] = target
            table.insert(merged, target)
        end
        for _, alternative in ipairs(row.keys) do
            alternative = type(alternative) == "table" and alternative or { alternative }
            local id = table.concat(alternative, " ")
            if not target.seen[id] then
                target.seen[id] = true
                table.insert(target.keys, alternative)
            end
        end
    end
    return merged
end

-- The groups to show. Each goes in the focused app's area or in "Everywhere", with a tag saying where
-- it comes from; the filter matches tags too, so "yabai" or "tmux" finds those groups.
local function groupsFor(app)
    local name, bundleID = app:name(), app:bundleID()
    local list = {}
    local function add(area, source, tag, groups)
        for _, group in ipairs(groups or {}) do
            if #group.rows > 0 then
                table.insert(list, {
                    area = area, source = source, tag = tag, title = group.title, rows = mergeRows(group.rows), folded = group.folded,
                })
            end
        end
    end
    if bundleID == "com.microsoft.VSCode" then add("app", "config", "keybindings.json", { { title = "Your keybindings", rows = vscodeRows() } }) end
    if bundleID == "org.alacritty" then add("app", "config", "alacritty.toml", { { title = "Your bindings", rows = alacrittyRows() } }) end
    add("app", "app", nil, (menuCache[cacheKey(app)] or {}).groups)
    if TERMINALS[bundleID] then add("app", "tmux", "tmux", tmuxGroups()) end
    local windowGroups = skhdGroups(name:lower())
    if windowGroups then
        add("everywhere", "wm", "yabai/skhd", windowGroups)
        add("everywhere", "wm", "yabai", { { title = "Mouse", rows = yabaiMouse() } })
    end
    add("everywhere", "hs", "Hammerspoon", registered)
    add("everywhere", "mac", "macOS", { { title = "System", rows = systemRows() } })
    return list
end
M.groupsFor, M.readMenus = groupsFor, readMenus -- for testing from the `hs` command line

-- Gruvbox, like the k9s skin; titles are coloured by where the group comes from, and the panel is
-- slightly see-through
local CSS = [[
:root { --bg: rgba(29, 32, 33, 0.97); --fg: #ebdbb2; --muted: #a89984; --faint: #7c6f64; --line: #32302f; --key: #282828;
  --key-border: #504945; --app: #fabd2f; --config: #fe8019; --tmux: #b8bb26; --wm: #83a598; --hs: #d3869b; --mac: #8ec07c; }
@media (prefers-color-scheme: light) {
  :root { --bg: rgba(251, 241, 199, 0.97); --fg: #3c3836; --muted: #7c6f64; --faint: #a89984; --line: #ebdbb2; --key: #f2e5bc;
    --key-border: #d5c4a1; --app: #b57614; --config: #af3a03; --tmux: #79740e; --wm: #076678; --hs: #8f3f71; --mac: #427b58; }
}
html, body { margin: 0; height: 100%; background: transparent; }
body { font: 13px/1.3 -apple-system, sans-serif; color: var(--fg); -webkit-user-select: none; cursor: default; }
.panel { box-sizing: border-box; height: 100%; display: flex; flex-direction: column; background: var(--bg);
  border: 1px solid var(--key-border); border-radius: 12px; overflow: hidden; }
header { display: flex; align-items: center; gap: 10px; padding: 10px 18px; border-bottom: 1px solid var(--line); }
header img { width: 24px; height: 24px; }
header > :not(input) { flex: none; }
h1 { font-size: 15px; font-weight: 600; margin: 0; }
input { box-sizing: border-box; margin-left: auto; flex: 0 1 400px; min-width: 160px; padding: 5px 10px; border-radius: 6px; border: 1px solid var(--key-border);
  background: var(--key); color: var(--fg); font: inherit; outline: none; }
.hint { color: var(--faint); font-size: 11px; border: 1px solid var(--key-border); border-radius: 4px; padding: 0 5px; }
main { flex: 1; min-height: 0; display: flex; overflow-y: auto; }
.area { flex: none; padding: 12px 18px 18px; }
.everywhere { border-left: 1px solid var(--line); }
.app[hidden] + .everywhere { border-left: none; }
.measure { position: absolute; left: -10000px; top: 0; visibility: hidden; }
h2 { font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); margin: 0 0 8px; }
.columns { display: flex; gap: 24px; align-items: flex-start; }
.measure { width: 272px; }
.column { flex: none; width: calc(272px + var(--extra, 0px)); }
.group { padding-bottom: 12px; }
.continued { font-weight: 400; color: var(--faint); }
.more { color: var(--muted); cursor: pointer; }
.more:hover { color: var(--fg); }
.head { display: flex; align-items: baseline; gap: 8px; border-bottom: 1px solid var(--line); padding-bottom: 2px; margin-bottom: 4px; }
h3 { font-size: 12px; font-weight: 600; margin: 0; color: var(--app); }
.src-config h3 { color: var(--config); }
.src-tmux h3 { color: var(--tmux); }
.src-wm h3 { color: var(--wm); }
.src-hs h3 { color: var(--hs); }
.src-mac h3 { color: var(--mac); }
.tag { margin-left: auto; font-size: 10px; color: var(--faint); }
ul { list-style: none; margin: 0; padding: 0; }
li { display: grid; grid-template-columns: 1fr auto; gap: 10px; align-items: start; padding: 1px 0; }
.keys { display: flex; align-items: center; gap: 3px; white-space: nowrap; }
kbd { font: 11.5px/17px -apple-system, sans-serif; padding: 0 5px; border-radius: 4px; background: var(--key); border: 1px solid var(--key-border); }
.or { color: var(--faint); font-size: 11px; padding: 0 1px; }
mark { background: none; color: var(--app); font-weight: 600; }
.empty { margin: auto; color: var(--muted); }
[hidden] { display: none !important; }
]]

-- The page is loaded once, when Hammerspoon starts. Opening the overlay calls render() with the app's
-- shortcuts instead of loading a new page, which made WebKit rebuild everything (and sometimes start
-- a new page process) on every open.
local SCRIPT = [==[
const input = document.querySelector("input");
const main = document.querySelector("main");
const empty = document.querySelector(".empty");
const icon = document.querySelector("header img");
const appName = document.querySelector("h1");
const hint = document.querySelector(".hint");
const measure = Object.assign(document.createElement("div"), { className: "measure" });
document.body.append(measure);
const areas = [...document.querySelectorAll(".area")].map((element) => ({
  element, name: element.dataset.area, title: element.querySelector("h2"), columns: element.querySelector(".columns"), groups: [],
}));
// Must match the CSS: column width and gap, the space below a group's header and below a group, and
// the width taken by the areas' padding, the line between them and the panel's border
const COLUMN_WIDTH = 272, GAP = 24, HEAD_SPACE = 4, GROUP_SPACE = 12, FRAME = 75;
// The header's gap, its right padding and the search field's smallest width
const HEADER_GAP = 10, HEADER_PADDING = 18, INPUT_MIN = 160;
// A group split across columns keeps at least this many rows in each part
const MIN_PART = 3;
let rows = [], unfolded = false;
// Set when the overlay opens: how tall a column can get before the window reaches its full height,
// how many columns fit on the screen, and how many fit in the window
let maxColumnHeight = Infinity, maxColumns = 2, columnsShown = 2;
// The narrowest the window gets: the header with the search field at its smallest
let minWidth = 0;

const columnsIn = (width) => Math.max(2, Math.floor((width - FRAME + 2 * GAP) / (COLUMN_WIDTH + GAP)));

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

// A group is its header and its rows; the elements shown are built from them on every layout
function buildGroup(group) {
  const head = node("div", "head");
  head.append(node("h3", null, group.title));
  if (group.tag) head.append(node("span", "tag", group.tag));
  const items = group.rows.map((row) => {
    const item = node("li");
    item.dataset.search = row.search;
    item.appendChild(node("span", "label", row.label)).dataset.text = row.label;
    const keys = item.appendChild(node("span", "keys"));
    row.keys.forEach((alternative, index) => {
      if (index > 0) keys.append(node("span", "or", "/"));
      for (const key of alternative) keys.append(node("kbd", null, key));
    });
    return item;
  });
  let more = null;
  if (group.folded) {
    more = node("li", "more");
    more.append(node("span", "label", "Show all " + items.length), node("span", "keys"));
    more.lastChild.append(node("kbd", null, "Tab"));
    more.addEventListener("click", toggleFolded);
  }
  return { className: "group src-" + group.source, head, rows: items, more, hidden: false };
}

// A folded group shows only its "Show all" row, until Tab opens it or a search matches its rows
function shownRows(group) {
  if (group.more && !unfolded && !input.value.trim()) return [group.more];
  return group.rows.filter((row) => !row.hidden);
}

function part(group, items, continued) {
  const element = node("div", group.className);
  const head = group.head.cloneNode(true);
  if (continued) head.firstChild.append(" ", node("span", "continued", "continued"));
  const list = node("ul");
  list.append(...items);
  element.append(head, list);
  return element;
}

// Heights of each visible group's header and rows in a column
function measureGroups(groups) {
  const parts = groups.map((group) => {
    const head = group.head.cloneNode(true);
    const list = node("ul");
    list.append(...shownRows(group));
    return { group, head, list };
  });
  measure.replaceChildren(...parts.flatMap(({ head, list }) => [head, list]));
  return parts.map(({ group, head, list }) => ({
    group,
    head: head.offsetHeight + HEAD_SPACE,
    rows: [...list.children].map((row) => ({ row, height: row.offsetHeight })),
  }));
}

const heightOf = (measured) => measured.reduce((sum, { head, rows }) => sum + head + GROUP_SPACE + rows.reduce((s, r) => s + r.height, 0), 0);

// Fills columns in order up to a height. A group that doesn't fit moves to the next column whole if
// it's short or only a few of its rows would fit; otherwise it continues at the top of the next column.
function pack(measured, limit) {
  const columns = [[]];
  let used = 0;
  for (const { group, head, rows: groupRows } of measured) {
    let start = 0;
    while (start < groupRows.length) {
      let height = head, end = start;
      while (end < groupRows.length && used + height + groupRows[end].height <= limit) height += groupRows[end++].height;
      const remaining = groupRows.length - start;
      if (end === groupRows.length) {
        columns.at(-1).push({ group, rows: groupRows.slice(start), continued: start > 0 });
        used += height + GROUP_SPACE;
        break;
      }
      if (used > 0 && (end - start < MIN_PART || remaining < 2 * MIN_PART)) {
        columns.push([]);
        used = 0;
        continue;
      }
      let take = Math.max(1, end - start);
      if (remaining - take < MIN_PART) take = Math.max(1, remaining - MIN_PART);
      columns.at(-1).push({ group, rows: groupRows.slice(start, start + take), continued: start > 0 });
      start += take;
      columns.push([]);
      used = 0;
    }
  }
  return columns;
}

// The lowest column height that fits everything into `count` columns, so they end about level
function flow(measured, count) {
  let low = heightOf(measured) / count, high = heightOf(measured) + 1000;
  for (let step = 0; step < 24; step++) {
    const middle = (low + high) / 2;
    if (pack(measured, middle).length <= count) high = middle;
    else low = middle;
  }
  return pack(measured, high);
}

// Flows each area's groups down its columns in order, filling a column to the full height before
// starting the next, then evens out the columns it used. If they need more than `count` columns,
// the areas share all of them so both end about as high, and the window scrolls.
function layout(count) {
  const measured = areas.map((area) => measureGroups(area.groups.filter((group) => !group.hidden)));
  let counts = measured.map((groups) => (groups.length ? pack(groups, maxColumnHeight).length : 0));
  if (counts[0] + counts[1] > count) {
    counts = measured.map((groups) => (groups.length ? count : 0));
    if (counts[0] && counts[1]) {
      const heights = measured.map(heightOf);
      let lowest = Infinity;
      for (let app = 1; app < count; app++) {
        const height = Math.max(heights[0] / app, heights[1] / (count - app));
        if (height < lowest) [lowest, counts] = [height, [app, count - app]];
      }
    }
  }
  empty.hidden = counts.some(Boolean);
  areas.forEach((area, index) => {
    area.element.hidden = !counts[index];
    if (!counts[index]) return area.columns.replaceChildren();
    area.columns.replaceChildren(...flow(measured[index], counts[index]).map((parts) => {
      const column = node("div", "column");
      column.append(...parts.map(({ group, rows: items, continued }) => part(group, items.map(({ row }) => row), continued)));
      return column;
    }));
  });
  measure.replaceChildren();
}

// The window size the content needs: as wide as its columns, and down to the lowest column, or with
// room for "No shortcuts match". Columns narrower than the header together are widened to fill it.
function contentSize() {
  const shown = areas.filter((area) => !area.element.hidden);
  main.style.setProperty("--extra", "0px");
  if (!shown.length) return { width: minWidth, height: Math.ceil(main.getBoundingClientRect().top + 100) };
  const width = shown.at(-1).element.getBoundingClientRect().right + 1;
  if (width < minWidth) {
    const columns = shown.reduce((count, area) => count + area.columns.children.length, 0);
    main.style.setProperty("--extra", (minWidth - width) / columns + "px");
  }
  return {
    width: Math.ceil(Math.max(minWidth, width)),
    height: Math.ceil(Math.max(...shown.map((area) => area.columns.getBoundingClientRect().bottom)) + 20),
  };
}

// Lays out again after filtering or folding, and has Hammerspoon fit the window to it. Typing only
// narrows it from the width it opened at, as fewer columns are needed; Tab can widen it.
function refresh(resize) {
  main.scrollTop = 0;
  layout(resize ? maxColumns : columnsShown);
  const size = contentSize();
  if (resize) columnsShown = columnsIn(size.width);
  window.webkit?.messageHandlers?.shortcuts?.postMessage(size);
}

function toggleFolded() {
  unfolded = !unfolded;
  refresh(true);
}

// Called by Hammerspoon with an app's shortcuts, while the window is at its largest. Returns the size
// the content needs, so the window opens at that size instead of mostly empty.
function render(data) {
  icon.hidden = !data.icon;
  icon.src = data.icon;
  appName.textContent = areas[0].title.textContent = data.app;
  minWidth = Math.ceil(appName.getBoundingClientRect().right + 2 * HEADER_GAP + INPUT_MIN + hint.getBoundingClientRect().width + HEADER_PADDING + 1);
  const groups = Array.isArray(data.groups) ? data.groups : [];
  for (const area of areas) area.groups = groups.filter((group) => group.area === area.name).map(buildGroup);
  rows = areas.flatMap((area) => area.groups.flatMap((group) => group.rows));
  input.value = "";
  unfolded = false;
  main.scrollTop = 0;
  for (const area of areas) area.element.hidden = false;
  maxColumnHeight = innerHeight - areas[0].columns.getBoundingClientRect().top - 20 - GROUP_SPACE;
  maxColumns = columnsIn(innerWidth);
  layout(maxColumns);
  input.focus();
  const size = contentSize();
  columnsShown = columnsIn(size.width);
  return size;
}

function highlight(label, query) {
  const text = label.dataset.text;
  const at = query ? text.toLowerCase().indexOf(query) : -1;
  if (at < 0) return void (label.textContent = text);
  const mark = node("mark", null, text.slice(at, at + query.length));
  label.replaceChildren(text.slice(0, at), mark, text.slice(at + query.length));
}

// Every word has to match, in any order: "shift cmd p" finds ⇧⌘P
input.addEventListener("input", () => {
  const query = input.value.trim().toLowerCase();
  const words = query.split(/\s+/).filter(Boolean);
  for (const row of rows) {
    row.hidden = !words.every((word) => row.dataset.search.includes(word));
    highlight(row.querySelector(".label"), query);
  }
  for (const area of areas) for (const group of area.groups) group.hidden = group.rows.every((row) => row.hidden);
  refresh(false);
});

// Tab opens or folds the folded groups. Escape clears the filter first, then closes.
document.addEventListener("keydown", (event) => {
  if (event.key === "Tab") {
    event.preventDefault();
    toggleFolded();
  } else if (event.key === "Escape") {
    event.preventDefault();
    if (input.value) {
      input.value = "";
      input.dispatchEvent(new Event("input"));
    } else {
      window.webkit?.messageHandlers?.shortcuts?.postMessage("close");
    }
  }
});

// Clicking (on "Show all", say) leaves the keyboard in the filter field
document.addEventListener("mousedown", (event) => {
  if (event.target !== input) event.preventDefault();
});

window.webkit?.messageHandlers?.shortcuts?.postMessage("ready");
]==]

local PAGE = table.concat({
    '<!doctype html><html><head><meta charset="utf-8"><style>', CSS, '</style></head><body><div class="panel"><header>',
    '<img alt="" hidden><h1></h1><input placeholder="Filter: a word, keys (shift cmd p), or yabai, tmux, macOS…" spellcheck="false">',
    '<span class="hint">esc</span></header><main>',
    '<section class="area app" data-area="app"><h2></h2><div class="columns"></div></section>',
    '<section class="area everywhere" data-area="everywhere"><h2>Everywhere</h2><div class="columns"></div></section>',
    '<p class="empty" hidden>No shortcuts match</p></main></div><script>', SCRIPT, "</script></body></html>",
})

-- Lets a search for "cmd shift p" find "⇧⌘P"
local SYMBOL_WORDS = {
    ["⌘"] = "cmd command", ["⌥"] = "alt option", ["⌃"] = "ctrl control", ["⇧"] = "shift", ["⇥"] = "tab",
    ["⎋"] = "esc escape", ["↩"] = "return enter", ["⌫"] = "delete backspace", ["⌦"] = "delete",
    ["←"] = "left", ["→"] = "right", ["↑"] = "up", ["↓"] = "down",
}
local function searchText(row, group)
    local chips = {}
    for _, alternative in ipairs(row.keys) do table.insert(chips, table.concat(alternative, " ")) end
    local keys = table.concat(chips, " ")
    for symbol, words in pairs(SYMBOL_WORDS) do keys = keys:gsub(symbol, " " .. words .. " ") end
    return table.concat({ row.label, group.title, group.tag or "", keys }, " "):lower()
end

-- App icons at header size, as data URLs (encoding the full-size icon took most of the opening time)
local icons = {}
local function iconURL(bundleID)
    if not bundleID then return nil end
    if icons[bundleID] == nil then
        local image = hs.image.imageFromAppBundle(bundleID)
        icons[bundleID] = image and image:setSize({ w = 48, h = 48 }):encodeAsURLString() or false
    end
    return icons[bundleID] or nil
end

-- What render() gets: the app's name and icon, and the groups with each row's search text
local function pageData(app)
    local groups = groupsFor(app)
    for _, group in ipairs(groups) do
        for _, row in ipairs(group.rows) do
            row.search, row.seen = searchText(row, group), nil
        end
    end
    return { app = app:name(), icon = iconURL(app:bundleID()) or "", groups = groups }
end

-- A complete page showing an app's shortcuts, for previews outside Hammerspoon
function M.previewHTML(app)
    local call = "<script>render(" .. hs.json.encode(pageData(app)) .. ")</script></body>"
    return (PAGE:gsub("</body>", function() return call end))
end

-- One window, created when Hammerspoon starts and then only shown and hidden: deleting a webview
-- twice (its delete finishes asynchronously, and closing it also ends its focus) crashes Hammerspoon.
-- It's a non-activating panel, so it takes the keyboard while the app you were in stays active.
local function hide(restoreFocus)
    M.queued = nil
    if M.pending then
        M.pending = nil
        M.revealTimer:stop()
    end
    if not M.visible then return end
    M.visible = false
    M.view:hide()
    if restoreFocus and M.previousWindow then M.previousWindow:focus() end
end

-- A frame of this size in the middle of the space the window can take
local function centred(w, h)
    local area = M.area
    w, h = math.min(w, area.w), math.min(h, area.h)
    return { x = area.x + (area.w - w) / 2, y = area.y + (area.h - h) / 2, w = w, h = h }
end

-- Shows the window centred at the size the content needs (or at full size if the page didn't answer)
local function reveal(size)
    if not M.pending then return end
    M.pending = nil
    M.revealTimer:stop()
    M.view:frame(centred(size and size.width or M.area.w, size and size.height or M.area.h))
    M.visible, M.hadFocus = true, false
    M.view:show()
    -- A non-activating panel gets the keyboard without switching apps; if another app's window keeps
    -- it (a system prompt, say), activate Hammerspoon instead so typing and Escape still work
    M.focusTimer = hs.timer.doAfter(0.05, function()
        if not M.visible then return end
        M.view:evaluateJavaScript("document.hasFocus()", function(focused)
            if M.visible and focused ~= true then M.view:hswindow():focus() end
        end)
    end)
end

-- Grows or shrinks the open window with its content (filtering, Tab), keeping it centred
local function fit(size)
    if not M.visible then return end
    local frame = M.view:frame()
    M.view:frame(centred(size.width or frame.w, size.height or frame.h))
end

local function render(script)
    M.view:evaluateJavaScript(script, function(size) reveal(type(size) == "table" and size or nil) end)
end

local function createView()
    -- The page posts "ready" once it has loaded, "close" on Escape, and its size when it changes
    M.messages = hs.webview.usercontent.new("shortcuts"):setCallback(function(message)
        local body = type(message) == "table" and message.body or message
        if type(body) == "table" then
            fit(body)
        elseif body == "close" then
            hide(true)
        elseif body == "ready" then
            M.pageReady = true
            if M.queued then render(M.queued) end
            M.queued = nil
        end
    end)
    M.view = hs.webview.new({ x = 0, y = 0, w = 100, h = 100 }, {}, M.messages)
        :windowStyle({ "borderless", "nonactivating" })
        :level(hs.drawing.windowLevels.modalPanel)
        :transparent(true)
        :shadow(true)
        :allowTextEntry(true)
        :html(PAGE)
    M.view:windowCallback(function(action, _, focused)
        if action ~= "focusChange" then return end
        -- Clicking anywhere else hides it, leaving the focus where you clicked
        if focused then
            M.hadFocus = true
        elseif M.visible and M.hadFocus then
            M.hideTimer = hs.timer.doAfter(0, function() hide(false) end)
        end
    end)
end

-- Shows the overlay for an app
function M.show(app)
    if not M.view then createView() end
    local window = app:focusedWindow()
    local screen = (window and window:screen() or hs.screen.mainScreen()):frame()
    local width, height = math.min(2200, screen.w * 0.9), screen.h * 0.9
    -- The most space it can take. The page lays out at this size and then asks for the size it needs.
    M.area = { x = screen.x + (screen.w - width) / 2, y = screen.y + (screen.h - height) / 2, w = width, h = height }
    M.view:frame(M.area)
    M.previousWindow, M.pending = window, true
    M.revealTimer = hs.timer.doAfter(0.5, function() reveal(nil) end)
    local script = "render(" .. hs.json.encode(pageData(app)) .. ")"
    if M.pageReady then render(script) else M.queued = script end
end

M.hide = hide

function M.toggle()
    if M.visible or M.pending then return hide(true) end
    local app = hs.application.frontmostApplication()
    if not app then return end
    if menuCache[cacheKey(app)] then
        M.show(app)
        if not isFresh(app) then readMenus(app) end
    else
        -- Never read before: wait for its menus
        readMenus(app, function() M.show(app) end)
    end
end

function M.start(mods, key)
    M.add("Hammerspoon", mods, key, "Show keyboard shortcuts")
    M.hotkey = hs.hotkey.bind(mods, key, M.toggle)

    M.menubar = hs.menubar.new()
    M.menubar:setTitle("⌘") -- until the icon is rendered
    M.menubar:setTooltip("Keyboard shortcuts (" .. combo(mods, key) .. ")")
    M.menubar:setClickCallback(M.toggle)

    M.watcher = hs.application.watcher.new(function(_, event, app)
        if event == hs.application.watcher.activated and app and app:bundleID() ~= hs.processInfo.bundleID and not isFresh(app) then
            readMenus(app)
        end
    end)
    M.watcher:start()
    createView() -- loads the page now rather than on the first open

    buildReader(function()
        readerReady = true
        setIcon()
        prewarm()
    end)
end

return M
