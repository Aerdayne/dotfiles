-- Keyboard shortcut overlay: shows the shortcuts available in the focused app, as a list or on a
-- drawing of the keyboard (Tab switches between them).
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
        -- Folded to one row until it's clicked or a search finds it, as it's longer than everything else together
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

-- Keyboards --------------------------------------------------------------------------------------

-- The Moonlander's layout as `moonlander` (configs/moonlander) last flashed it: QMK's key positions,
-- Oryx's keymap.c and the layer names
local MOONLANDER = HOME .. "/.local/share/moonlander"
local ZSA_VENDOR_ID = 0x3297

local function readFile(path)
    local file = io.open(path)
    if not file then return nil end
    local text = file:read("a")
    file:close()
    return text
end

-- Each layer's keycodes, from the LAYOUT_moonlander(…) arrays in keymap.c
local function keymapLayers(text)
    local layers = {}
    for index, body in text:gmatch("%[(%d+)%]%s*=%s*LAYOUT_moonlander(%b())") do
        local codes, depth, start = {}, 0, 2
        for i = 2, #body - 1 do
            local char = body:sub(i, i)
            if char == "(" then depth = depth + 1 elseif char == ")" then depth = depth - 1 end
            if char == "," and depth == 0 then
                table.insert(codes, (body:sub(start, i - 1):gsub("%s", "")))
                start = i + 1
            end
        end
        local last = body:sub(start, -2):gsub("%s", "")
        if last ~= "" then table.insert(codes, last) end
        layers[tonumber(index) + 1] = codes
    end
    return layers
end

local moonlander = {}
local function moonlanderLayout()
    local attributes = hs.fs.attributes(MOONLANDER .. "/keymap.c")
    if not attributes then return nil end
    if moonlander.modified ~= attributes.modification then
        local okGeometry, geometry = pcall(hs.json.decode, readFile(MOONLANDER .. "/keyboard.json") or "")
        local okLayout, layout = pcall(hs.json.decode, readFile(MOONLANDER .. "/layout.json") or "")
        local keys = {}
        for _, key in ipairs(okGeometry and geometry and geometry.layouts and geometry.layouts.LAYOUT and geometry.layouts.LAYOUT.layout or {}) do
            table.insert(keys, { x = key.x, y = key.y, w = key.w or 1, h = key.h or 1 })
        end
        local layers, names = keymapLayers(readFile(MOONLANDER .. "/keymap.c") or ""), {}
        for _, layer in ipairs(okLayout and layout and layout.layers or {}) do names[layer.position + 1] = layer.title end
        local valid = #keys > 0 and #layers > 0
        for _, codes in ipairs(layers) do valid = valid and #codes == #keys end
        moonlander = { modified = attributes.modification, data = valid and { keys = keys, layers = layers, names = names } or nil }
    end
    return moonlander.data
end

local function moonlanderAttached()
    for _, device in ipairs(hs.usb.attachedDevices() or {}) do
        if device.vendorID == ZSA_VENDOR_ID and (device.productName or ""):find("Moonlander") then return true end
    end
    return false
end

-- What the keyboard layout types on each key of the built-in keyboard, and its shape, from the reader
local typedKeys
local function readTypedKeys()
    M.keysTask = hs.task.new(READER, function(code, output)
        local ok, keys = pcall(hs.json.decode, output)
        if code == 0 and ok then typedKeys = keys end
    end, { "keys" })
    M.keysTask:start()
end

-- The keyboard the keyboard view draws: the Moonlander while it's plugged in, else the built-in one
local function keyboardData()
    local layout = moonlanderAttached() and moonlanderLayout()
    return { board = layout and "moonlander" or "builtin", moonlander = layout or nil, typed = typedKeys }
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
  --key-border: #504945; --app: #fabd2f; --config: #fe8019; --tmux: #b8bb26; --wm: #83a598; --hs: #d3869b; --mac: #8ec07c; --warn: #fb4934; }
@media (prefers-color-scheme: light) {
  :root { --bg: rgba(251, 241, 199, 0.97); --fg: #3c3836; --muted: #7c6f64; --faint: #a89984; --line: #ebdbb2; --key: #f2e5bc;
    --key-border: #d5c4a1; --app: #b57614; --config: #af3a03; --tmux: #79740e; --wm: #076678; --hs: #8f3f71; --mac: #427b58; --warn: #9d0006; }
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
main { flex: 1; min-height: 0; display: flex; overflow-x: hidden; overflow-y: auto; }
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

/* The keyboard view: chips for the modifiers and layers, the keyboard, and the shortcuts under it */
.board-view { box-sizing: border-box; flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 10px 18px 14px; }
.board-bar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; }
.chips { display: flex; flex-wrap: wrap; gap: 4px; }
.chip { font: 12px/1 -apple-system, sans-serif; color: var(--fg); background: var(--key); border: 1px solid var(--key-border);
  border-radius: 5px; padding: 4px 7px; display: inline-flex; align-items: center; gap: 5px; }
.chip .n { font-size: 10px; color: var(--faint); }
.chip:hover { border-color: var(--muted); }
.chip.on { background: var(--fg); border-color: var(--fg); color: var(--key); }
.chip.on .n { color: inherit; opacity: 0.7; }
.chip.peek { outline: 2px solid var(--app); outline-offset: 1px; }
.board { position: relative; flex: none; align-self: center; }
.k { position: absolute; box-sizing: border-box; display: grid; grid-template-rows: auto 1fr; overflow: hidden; color: var(--fg);
  background: var(--key); border: 1px solid var(--key-border); border-radius: calc(var(--u) * 0.13);
  padding: calc(var(--u) * 0.05) calc(var(--u) * 0.08) calc(var(--u) * 0.08); }
.k .lg { font: calc(var(--u) * 0.2)/1.05 ui-monospace, Menlo, monospace; color: var(--faint); white-space: nowrap; overflow: hidden; }
.k .act { align-self: center; display: grid; justify-items: center; gap: 1px; min-width: 0; text-align: center; }
.k .big { font-size: calc(var(--u) * 0.4); line-height: 1; font-weight: 600; }
.k .small { font-size: calc(var(--u) * 0.17); line-height: 1.1; max-width: 100%; overflow: hidden; overflow-wrap: break-word;
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; }
.k .second { color: var(--muted); }
.k.hit .small { -webkit-line-clamp: 2; }
.k::after { content: ""; position: absolute; inset: auto 0 0 0; height: 3px; background: var(--src, transparent); }
.k .mark { position: absolute; top: calc(var(--u) * 0.04); right: calc(var(--u) * 0.07); font: 700 calc(var(--u) * 0.2)/1 -apple-system, sans-serif;
  color: var(--warn); }
.s-app { --src: var(--app); } .s-config { --src: var(--config); } .s-tmux { --src: var(--tmux); }
.s-wm { --src: var(--wm); } .s-hs { --src: var(--hs); } .s-mac { --src: var(--mac); }
.k.bound { background: color-mix(in srgb, var(--src) 16%, var(--key)); border-color: color-mix(in srgb, var(--src) 50%, var(--key-border)); }
.k.faint .act, .k.free .act { color: var(--faint); }
.k.dead .act { color: var(--warn); }
.k.free { border-style: dashed; }
.k.lit { background: var(--fg); border-color: var(--fg); color: var(--key); }
.k.lit .lg, .k.lit .mark { color: inherit; }
.k.seq, .k.hit { box-shadow: inset 0 0 0 2px var(--app); }
.k.ping { box-shadow: inset 0 0 0 2px var(--fg); }
.k.dim { opacity: 0.3; }
.k.trans .lg { opacity: 0.5; }
.board-key { display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 11px; color: var(--muted); }
.board-key i { font-style: normal; font-weight: 700; color: var(--warn); }
.board-key b { display: inline-block; width: 10px; height: 3px; border-radius: 1px; background: var(--src); vertical-align: middle; margin-right: 5px; }
.k { isolation: isolate; }
.k.used::before { content: ""; position: absolute; inset: 0; z-index: -1; background: var(--fg); opacity: calc(0.03 + var(--heat, 0) * 0.13); }
.k .pills { display: flex; flex-wrap: wrap; justify-content: center; gap: 2px; }
.k .pill { font-size: calc(var(--u) * 0.165); line-height: 1.35; padding: 0 calc(var(--u) * 0.05); border-radius: 3px; white-space: nowrap;
  background: color-mix(in srgb, var(--fg) 14%, transparent); }
.board-details { flex: 1; min-height: 0; overflow-x: hidden; overflow-y: auto; border-top: 1px solid var(--line); padding-top: 8px;
  padding-right: 10px; }
/* Thin scroll bars in the panel's colours, instead of the system's full-size ones (shown while a mouse is
   connected). The window is made wider by their width (SCROLLBAR), so they don't cover the last column. */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track, ::-webkit-scrollbar-corner { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--key-border); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--faint); }
.board-details > h3 { color: var(--fg); margin-bottom: 2px; }
.board-details .sub { font-size: 11.5px; color: var(--muted); margin: 0 0 8px; }
.board-details li.note .label { color: var(--muted); }
.board-details .combos { display: flex; flex-wrap: wrap; gap: 4px; margin: 4px 0 10px; }
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
const hints = [...document.querySelectorAll("header .hint")];
const measure = Object.assign(document.createElement("div"), { className: "measure" });
document.body.append(measure);
const areas = [...document.querySelectorAll(".area")].map((element) => ({
  element, name: element.dataset.area, title: element.querySelector("h2"), columns: element.querySelector(".columns"), groups: [],
}));
// Must match the CSS: column width and gap, the space below a group's header and below a group, and
// the width taken by the areas' padding, the line between them and the panel's border
const COLUMN_WIDTH = 272, GAP = 24, HEAD_SPACE = 4, GROUP_SPACE = 12, FRAME = 75;
// The header's gap, its right padding and the search field's smallest width, then the keyboard view's
// side and bottom padding
const HEADER_GAP = 10, HEADER_PADDING = 18, INPUT_MIN = 160, BOARD_PADDING = 18, BOARD_BOTTOM = 14;
// The scroll bars' width, and the space between the keyboard view's list and its scroll bar, from the CSS
const SCROLLBAR = 8, BOARD_GUTTER = 10;
// A group split across columns keeps at least this many rows in each part
const MIN_PART = 3;
let rows = [], unfolded = false;
// The app in front. Its menus' groups have no tag in the list, where the app's area is named after it,
// but searching for its name finds them, and the keyboard view tags them with it.
let appTitle = "";
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
    // What the filter matches: words in the description, group and tag, and each shortcut's keys
    item.haystack = [row.label, group.title, groupTag(group)].join(" ").toLowerCase();
    item.combos = row.keys.flat().flatMap((step) => expandRange(step).map(parseKey).filter(Boolean));
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
    more.addEventListener("click", toggleFolded);
  }
  return { className: "group src-" + group.source, head, rows: items, more, hidden: false };
}

// A folded group shows only its "Show all" row, until it's clicked or a search matches its rows
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

// The lowest column height that fits everything into `count` columns, so they end about level, and
// no lower than `minHeight`
function flow(measured, count, minHeight = 0) {
  let low = Math.max(minHeight, heightOf(measured) / count), high = heightOf(measured) + 1000;
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
  const height = Math.ceil(Math.max(...shown.map((area) => area.columns.getBoundingClientRect().bottom)) + 20);
  // Taller than the screen allows, it scrolls: room for the scroll bar, so it doesn't cover the last column
  return { width: Math.ceil(Math.max(minWidth, width) + (height > full.height ? SCROLLBAR : 0)), height };
}

// Lays out again after filtering or folding, and has Hammerspoon fit the window to it. Typing only
// narrows it from the width it opened at, as fewer columns are needed; unfolding can widen it.
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
  full = { width: innerWidth, height: innerHeight };
  viewHint.textContent = view === "board" ? "⇥ list" : "⇥ keyboard";
  main.hidden = false;
  boardView.hidden = true;
  minWidth = Math.ceil(appName.getBoundingClientRect().right + HEADER_GAP + INPUT_MIN + HEADER_PADDING + 1
    + hints.reduce((sum, hint) => sum + HEADER_GAP + hint.getBoundingClientRect().width, 0));
  const groups = Array.isArray(data.groups) ? data.groups : [];
  appTitle = data.app;
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
  setupBoard(data.keyboard, groups, data.app);
  return view === "board" ? showBoard() : size;
}

function highlight(label, query) {
  const text = label.dataset.text;
  const at = query ? text.toLowerCase().indexOf(query) : -1;
  if (at < 0) return void (label.textContent = text);
  const mark = node("mark", null, text.slice(at, at + query.length));
  label.replaceChildren(text.slice(0, at), mark, text.slice(at + query.length));
}

// The filter. Words search the descriptions, group names and tags. Modifier names (cmd, shift, alt, ctrl,
// hyper, fn, or ⌘⇧⌥⌃) and a key (w, 3, tab, space, f5…) search the shortcuts: with a key, the modifiers
// have to be exactly those, so "cmd w" finds ⌘W and not ⇧⌘W. A key name like "tab" on its own matches
// descriptions too.
const QUERY_MODS = {
  cmd: "cmd", command: "cmd", "⌘": "cmd", shift: "shift", "⇧": "shift", alt: "alt", opt: "alt", option: "alt", "⌥": "alt",
  ctrl: "ctrl", control: "ctrl", "⌃": "ctrl", fn: "fn", hyper: "hyper",
};
const QUERY_KEYS = {
  space: "space", tab: "tab", esc: "escape", escape: "escape", return: "return", enter: "return", delete: "delete", backspace: "delete",
  left: "left", right: "right", up: "up", down: "down", home: "home", end: "end", pageup: "pageup", pagedown: "pagedown",
};

function parseQuery(text) {
  const query = { words: [], keyNames: [], mods: new Set(), key: null };
  for (const token of text.trim().toLowerCase().split(/[\s+]+/).filter(Boolean)) {
    const symbols = MOD_NAMES[token[0]] && token.length > 1 && parseKey(token.toUpperCase());
    if (QUERY_MODS[token]) {
      query.mods.add(QUERY_MODS[token]);
    } else if ([...token].length === 1) {
      query.key = SHIFTED[token] || token;
      if (SHIFTED[token]) query.mods.add("shift");
    } else if (QUERY_KEYS[token] || /^f\d{1,2}$/.test(token)) {
      query.keyNames.push(token);
    } else if (symbols) { // ⌘w, ⇧⌘p
      symbols.mods.forEach((mod) => query.mods.add(mod));
      query.key = symbols.key;
    } else {
      query.words.push(token);
    }
  }
  query.empty = !query.words.length && !query.keyNames.length && !query.mods.size && !query.key;
  return query;
}

const allMods = (mods) => new Set([...mods].flatMap((mod) => (mod === "hyper" ? MODS : [mod])));

// Whether a shortcut matches: `text` is its description, group and tag, `combos` its keys ({ mods, key })
function matchesQuery(query, text, combos) {
  if (!query.words.every((word) => text.includes(word))) return false;
  // With modifiers, a key name is the key ("cmd tab" is ⌘⇥); alone it can be a word too ("tab")
  const keyNames = query.mods.size ? query.keyNames : query.keyNames.filter((name) => !text.includes(name));
  if (keyNames.length > 1 || (keyNames.length && query.key)) return false;
  const key = query.key || (keyNames.length ? QUERY_KEYS[keyNames[0]] || keyNames[0] : null);
  if (!key && !query.mods.size) return true;
  const wanted = allMods(query.mods);
  return combos.some((combo) => {
    if (key && combo.key !== key) return false;
    const mods = allMods(combo.mods);
    if (key && wanted.size) return mods.size === wanted.size && [...wanted].every((mod) => mods.has(mod));
    return [...wanted].every((mod) => mods.has(mod));
  });
}

function filterList() {
  const text = input.value.trim().toLowerCase();
  const query = parseQuery(input.value);
  for (const row of rows) {
    row.hidden = !query.empty && !matchesQuery(query, row.haystack, row.combos);
    highlight(row.querySelector(".label"), text);
  }
  for (const area of areas) for (const group of area.groups) group.hidden = group.rows.every((row) => row.hidden);
}

// The list is filtered when it's shown again, not while typing in the keyboard view
input.addEventListener("input", () => {
  if (view === "board") return paintBoard(true);
  filterList();
  refresh(false);
});

// The keys that scroll a long list without a mouse, which the one-line filter field has no use for:
// ↑ and ↓ by a few rows, Page Up and Page Down by a page, ⌘↑ and ⌘↓ (or Home and End) to either end
function scrollByKey(event) {
  if (event.shiftKey || event.altKey || event.ctrlKey) return false;
  const pane = view === "board" ? details : main;
  const ends = { Home: 0, End: pane.scrollHeight };
  if (event.metaKey) Object.assign(ends, { ArrowUp: 0, ArrowDown: pane.scrollHeight });
  if (event.key in ends) {
    pane.scrollTo({ top: ends[event.key], behavior: "smooth" });
    return true;
  }
  const step = event.metaKey ? undefined : { ArrowDown: 60, ArrowUp: -60, PageDown: pane.clientHeight * 0.9, PageUp: -pane.clientHeight * 0.9 }[event.key];
  if (step === undefined) return false;
  pane.scrollBy({ top: step, behavior: event.repeat ? "auto" : "smooth" });
  return true;
}

// Tab switches between the list and the keyboard. In the keyboard, tmux's prefix (⌃Z) shows what the
// keys do after it, as tmux waits for the next key; pressing it again goes back. Escape clears the
// filter first, then closes.
document.addEventListener("keydown", (event) => {
  if (scrollByKey(event)) {
    event.preventDefault();
  } else if (event.key === "Tab") {
    event.preventDefault();
    setView(view === "list" ? "board" : "list");
  } else if (view === "board" && kb?.prefix && isPrefix(event)) {
    event.preventDefault();
    Object.assign(pick, { combo: pick.combo === "prefix" ? null : "prefix", peek: null, layer: 0 });
    paintBoard(true);
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

// Keyboard view ------------------------------------------------------------------------------------
// The keyboard with what each key does under the modifiers held down (or picked on a chip): the
// Moonlander while it's plugged in, else the built-in keyboard. Typing lights the keys that match.

const boardView = document.querySelector(".board-view");
const board = boardView.querySelector(".board");
const modChips = boardView.querySelector(".mods"), layerChips = boardView.querySelector(".layers");
const freeChip = boardView.querySelector(".free"), boardKey = boardView.querySelector(".board-key");
const details = boardView.querySelector(".board-details");
const viewHint = document.querySelector(".view-hint");
let view = "list", full = { width: innerWidth, height: innerHeight }, kb = null;
// The combination picked on a chip and the one held down, the layer, and the key or row pointed at
const pick = { combo: null, peek: null, armed: false, layer: 0, free: false, hover: null, row: null };

const MOD_NAMES = { "⌃": "ctrl", "⌥": "alt", "⇧": "shift", "⌘": "cmd" };
const MODS = ["ctrl", "alt", "shift", "cmd"];
const NAMED_KEYS = {
  Space: "space", "⇥": "tab", "↩": "return", "⌤": "return", "⎋": "escape", "⌫": "delete", "⌦": "forwarddelete",
  "←": "left", "→": "right", "↑": "up", "↓": "down", "↖": "home", "↘": "end", "⇞": "pageup", "⇟": "pagedown",
};
// Menus show some shortcuts by their shifted character (⌘+, ⌘?): those are the unshifted key with ⇧
const SHIFTED = {
  "~": "`", "!": "1", "@": "2", "#": "3", $: "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
  _: "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", '"': "'", "<": ",", ">": ".", "?": "/",
};
// Chips in a fixed order, so a combination is always in the same place
const COMBO_ORDER = ["cmd", "shift+cmd", "alt+cmd", "alt+shift+cmd", "ctrl+cmd", "ctrl+shift+cmd", "ctrl+alt+cmd", "alt", "alt+shift",
  "ctrl", "ctrl+shift", "ctrl+alt", "ctrl+alt+shift", "hyper", "fn", "prefix"];
// The binding a key shows first: skhd and Hammerspoon get keys before macOS, and macOS before apps
const RANK = { wm: 0, hs: 0, mac: 1, config: 2, tmux: 2, app: 3 };
const GLOBAL = new Set(["wm", "hs"]), LOCAL = new Set(["app", "config", "tmux"]);
const ARROWS = { left: "←", down: "↓", up: "↑", right: "→" };

// "⌥⇧H" -> { mods: alt shift, key: "h" }, or null for mouse actions and keys that aren't on a keyboard
function parseKey(text) {
  const mods = new Set();
  let rest = text;
  if (rest.startsWith("fn ")) { mods.add("fn"); rest = rest.slice(3); }
  if (rest.startsWith("Hyper ")) { MODS.forEach((mod) => mods.add(mod)); rest = rest.slice(6); }
  while (rest.length > 1 && MOD_NAMES[rest[0]]) { mods.add(MOD_NAMES[rest[0]]); rest = rest.slice(1); }
  let key = NAMED_KEYS[rest] || (/^F\d{1,2}$/.test(rest) ? rest.toLowerCase() : [...rest].length === 1 ? rest.toLowerCase() : null);
  if (!key) return null;
  if (SHIFTED[key]) { key = SHIFTED[key]; mods.add("shift"); }
  return { mods, key };
}

// A combination's id: its modifiers in macOS's order, with "hyper" for all four
function comboId(mods) {
  const hyper = MODS.every((mod) => mods.has(mod));
  return (mods.has("fn") ? ["fn"] : []).concat(hyper ? ["hyper"] : MODS.filter((mod) => mods.has(mod))).join("+");
}
function comboLabel(id) {
  if (id === "prefix") return "tmux " + kb.prefix.text;
  return id.split("+").map((mod) => ({ fn: "fn ", ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", hyper: "Hyper" })[mod]).join("");
}
const comboOrder = (id) => (COMBO_ORDER.includes(id) ? COMBO_ORDER.indexOf(id) : COMBO_ORDER.length);

// Whether a keydown is tmux's prefix. By the key's position, so it works in any input source.
function isPrefix(event) {
  const code = event.code || "";
  const key = code.startsWith("Key") ? code.slice(3).toLowerCase() : code.startsWith("Digit") ? code.slice(5) : code === "Space" ? "space" : null;
  return key === kb.prefix.key
    && MODS.every((mod) => kb.prefix.mods.has(mod) === event[{ ctrl: "ctrlKey", alt: "altKey", shift: "shiftKey", cmd: "metaKey" }[mod]]);
}

// "⌥1–9" -> ⌥1 … ⌥9
function expandRange(text) {
  const range = text.match(/^(.*?)(\d)–(\d)$/);
  if (!range) return [text];
  const keys = [];
  for (let digit = +range[2]; digit <= +range[3]; digit++) keys.push(range[1] + digit);
  return keys;
}

// A binding for each key a row's shortcut is on. Chords (⌘K, then ⌘I) and copy mode's keys aren't drawn.
const groupTag = (group) => group.tag || (group.source === "app" ? appTitle : "");

function collectBindings(groups) {
  const bindings = [];
  for (const [groupIndex, group] of groups.entries()) {
    if (group.source === "tmux" && group.title === "Copy mode") continue;
    const after = group.source === "tmux" && group.title.match(/^After (\S+)/);
    if (after && !kb.prefix) kb.prefix = { text: after[1], ...parseKey(after[1]) };
    for (const row of group.rows) {
      for (const alternative of row.keys) {
        if (alternative.length !== 1) continue;
        for (const text of expandRange(alternative[0])) {
          const parsed = parseKey(text);
          const combo = parsed && (after ? "prefix" : comboId(parsed.mods));
          if (!combo) continue;
          bindings.push({ id: bindings.length, combo, key: parsed.key, mods: parsed.mods, text, shown: alternative[0], label: row.label,
            source: group.source, haystack: [row.label, group.title, groupTag(group)].join(" ").toLowerCase(),
            shifted: !!after && parsed.mods.has("shift"), groupIndex, groupTitle: group.title, tag: groupTag(group), folded: !!group.folded });
        }
      }
    }
  }
  return bindings;
}

// What a key shows for a binding: an arrow and a verb for directions, else the label (a menu item's own name)
function capText(binding) {
  const label = binding.label.split(" › ").at(-1);
  const direction = label.match(/^(Focus|Move|Insert|Grow|Shrink|Resize pane) (left|down|up|right)$/i);
  const text = direction
    ? { big: ARROWS[direction[2].toLowerCase()], small: direction[1].replace(/^Resize pane$/i, "resize").toLowerCase() }
    : { small: label };
  if (binding.shifted) text.small = "⇧ " + text.small;
  return text;
}

// Moonlander keycodes (QMK's names, as in Oryx's keymap.c): [legend, the key's name in a shortcut, modifier]
const QMK = {
  KC_GRAVE: ["`", "`"], KC_GRV: ["`", "`"], KC_MINUS: ["-", "-"], KC_MINS: ["-", "-"], KC_EQUAL: ["=", "="], KC_EQL: ["=", "="],
  KC_LBRC: ["[", "["], KC_RBRC: ["]", "]"], KC_BSLS: ["\\", "\\"], KC_SCLN: [";", ";"], KC_QUOTE: ["'", "'"], KC_QUOT: ["'", "'"],
  KC_COMMA: [",", ","], KC_COMM: [",", ","], KC_DOT: [".", "."], KC_SLASH: ["/", "/"], KC_SLSH: ["/", "/"],
  KC_TAB: ["⇥", "tab"], KC_SPACE: ["Space", "space"], KC_SPC: ["Space", "space"], KC_ENTER: ["↩", "return"], KC_ENT: ["↩", "return"],
  KC_ESCAPE: ["Esc", "escape"], KC_ESC: ["Esc", "escape"], KC_BSPC: ["⌫", "delete"], KC_DELETE: ["⌦", "forwarddelete"], KC_DEL: ["⌦", "forwarddelete"],
  KC_LEFT: ["←", "left"], KC_RIGHT: ["→", "right"], KC_RGHT: ["→", "right"], KC_UP: ["↑", "up"], KC_DOWN: ["↓", "down"],
  KC_HOME: ["Home", "home"], KC_END: ["End", "end"], KC_PAGE_UP: ["PgUp", "pageup"], KC_PGUP: ["PgUp", "pageup"],
  KC_PAGE_DOWN: ["PgDn", "pagedown"], KC_PGDN: ["PgDn", "pagedown"], KC_CAPS: ["Caps"],
  KC_LEFT_SHIFT: ["⇧", null, "shift"], KC_LSFT: ["⇧", null, "shift"], KC_RIGHT_SHIFT: ["⇧", null, "shift"], KC_RSFT: ["⇧", null, "shift"],
  KC_LEFT_CTRL: ["⌃", null, "ctrl"], KC_LCTL: ["⌃", null, "ctrl"], KC_RIGHT_CTRL: ["⌃", null, "ctrl"], KC_RCTL: ["⌃", null, "ctrl"],
  KC_LEFT_ALT: ["⌥", null, "alt"], KC_LALT: ["⌥", null, "alt"], KC_RIGHT_ALT: ["⌥", null, "alt"], KC_RALT: ["⌥", null, "alt"],
  KC_LEFT_GUI: ["⌘", null, "cmd"], KC_LGUI: ["⌘", null, "cmd"], KC_RIGHT_GUI: ["⌘", null, "cmd"], KC_RGUI: ["⌘", null, "cmd"],
  KC_HYPR: ["Hyper", null, "hyper"], KC_MEH: ["Meh"],
  KC_MEDIA_PLAY_PAUSE: ["⏯"], KC_MEDIA_PREV_TRACK: ["⏮"], KC_MEDIA_NEXT_TRACK: ["⏭"], KC_AUDIO_MUTE: ["Mute"],
  KC_AUDIO_VOL_UP: ["Vol +"], KC_AUDIO_VOL_DOWN: ["Vol −"], KC_MS_BTN1: ["Click"], KC_MS_BTN2: ["Right click"], KC_MS_BTN3: ["Middle click"],
  KC_MS_UP: ["Mouse ↑"], KC_MS_DOWN: ["Mouse ↓"], KC_MS_LEFT: ["Mouse ←"], KC_MS_RIGHT: ["Mouse →"], KC_MS_WH_UP: ["Wheel ↑"],
  KC_MS_WH_DOWN: ["Wheel ↓"], QK_BOOT: ["Reset"], KC_KP_PLUS: ["+"], KC_KP_MINUS: ["−"], KC_KP_ENTER: ["↩"], KC_PSCR: ["Print"],
  KC_LPRN: ["("], KC_RPRN: [")"], KC_PIPE: ["|"], KC_LCBR: ["{"], KC_RCBR: ["}"], KC_COLN: [":"], KC_CIRC: ["^"], KC_LABK: ["<"],
  KC_RABK: [">"], KC_ASTR: ["*"], KC_AMPR: ["&"], KC_HASH: ["#"], RGB_TOG: ["Light"], RGB_MODE_FORWARD: ["Effect"],
  RGB_VAI: ["Bright +"], RGB_VAD: ["Bright −"], RGB_SPI: ["Speed +"], RGB_SPD: ["Speed −"], RGB_HUI: ["Hue +"], RGB_HUD: ["Hue −"],
  RGB_SAI: ["Sat +"], RGB_SAD: ["Sat −"], TOGGLE_LAYER_COLOR: ["Layer colours"],
};
const WRAPPERS = { LCTL: "⌃", RCTL: "⌃", C: "⌃", LSFT: "⇧", RSFT: "⇧", S: "⇧", LALT: "⌥", RALT: "⌥", A: "⌥", LGUI: "⌘", RGUI: "⌘", G: "⌘" };

// A Moonlander keycode -> { legend, char (the key's name in a shortcut), mod, hold (the layer it holds) }
function qmkKey(code) {
  let match;
  if ((match = code.match(/^(\w+)\((.*)\)$/)) && WRAPPERS[match[1]]) return { legend: WRAPPERS[match[1]] + qmkKey(match[2]).legend };
  if ((match = code.match(/^(?:MO|TG|TT|OSL|TO|DF)\((\d+)\)$/))) return { legend: "", hold: +match[1] };
  if ((match = code.match(/^LT\((\d+),(\w+)\)$/))) return { ...qmkKey(match[2]), hold: +match[1] };
  if (code === "KC_TRANSPARENT" || code === "KC_TRNS" || code === "_______") return { legend: "", trans: true };
  if (code === "KC_NO" || code === "XXXXXXX") return { legend: "", blank: true };
  if (QMK[code]) return { legend: QMK[code][0], char: QMK[code][1] || null, mod: QMK[code][2] || null };
  if ((match = code.match(/^KC_([A-Z])$/))) return { legend: match[1], char: match[1].toLowerCase() };
  if ((match = code.match(/^KC_(\d)$/))) return { legend: match[1], char: match[1] };
  if ((match = code.match(/^KC_F(\d{1,2})$/))) return { legend: "F" + match[1], char: "f" + match[1] };
  return { legend: code.replace(/^[A-Z]+_/, "").replace(/_/g, " ").toLowerCase() };
}

// The built-in keyboard by key code, ANSI or ISO, labelled with what the layout types; US keys until the reader says
const US_KEYS = [..."asdfhgzxcv§bqweryt123465=97-80]ou[ip", "", ..."lj'k;\\,/nm.", "", "", "`"];
const SPECIAL = {
  36: ["↩", "return"], 48: ["⇥", "tab"], 49: ["", "space"], 51: ["⌫", "delete"], 53: ["esc", "escape"], 57: ["⇪"],
  56: ["⇧", null, "shift"], 60: ["⇧", null, "shift"], 59: ["⌃", null, "ctrl"], 58: ["⌥", null, "alt"], 61: ["⌥", null, "alt"],
  55: ["⌘", null, "cmd"], 54: ["⌘", null, "cmd"], 63: ["fn", null, "fn"], 123: ["←", "left"], 124: ["→", "right"], 125: ["↓", "down"], 126: ["↑", "up"],
};
const F_KEYS = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111];
function builtinKeys(typed) {
  const iso = typed.shape === "ISO", keys = [];
  const add = (code, x, y, w, h) => {
    const special = SPECIAL[code];
    const char = special ? special[1] || null : F_KEYS.includes(code) ? "f" + (F_KEYS.indexOf(code) + 1) : typed.keys?.[code]?.base ?? US_KEYS[code] ?? null;
    const legend = special ? special[0] : F_KEYS.includes(code) ? "F" + (F_KEYS.indexOf(code) + 1) : (char || "").toUpperCase();
    keys.push({ x, y, w, h, base: { legend, char, mod: special?.[2] || null } });
  };
  let x = 0;
  for (const code of [53, ...F_KEYS]) { add(code, x, 0, code === 53 ? 1.5 : 1, 0.7); x += code === 53 ? 1.5 : 1; }
  const row = (y, items) => {
    let left = 0;
    for (const [code, w = 1] of items) { add(code, left, y, w, 1); left += w; }
  };
  const letters = (codes) => codes.map((code) => [code]);
  row(0.85, [[iso ? 10 : 50], ...letters([18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]), [51, 1.5]]);
  row(1.85, [[48, 1.5], ...letters([12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]), iso ? [36, 1] : [42, 1]]);
  row(2.85, [[57, 1.75], ...letters([0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]), ...(iso ? [[42, 1], [36, 0.75]] : [[36, 1.75]])]);
  row(3.85, [...(iso ? [[56, 1.25], [50, 1]] : [[56, 2.25]]), ...letters([6, 7, 8, 9, 11, 45, 46, 43, 47, 44]), [60, 2.25]]);
  row(4.85, [[63], [59], [58], [55, 1.25], [49, 5], [54, 1.25], [61], [123]]);
  add(126, 12.5, 4.85, 1, 0.5);
  add(125, 12.5, 5.35, 1, 0.5);
  add(124, 13.5, 4.85, 1, 1);
  if (iso) keys.find((key) => key.base.char === "return" && key.w === 0.75).base.legend = "";
  return keys;
}

const SOURCE_NAMES = { config: "your bindings", tmux: "tmux", wm: "yabai", hs: "Hammerspoon", mac: "macOS" };

function setupBoard(keyboard, groups, appTitle) {
  keyboard = keyboard || {};
  const typed = keyboard.typed || {};
  kb = { prefix: null, option: {}, names: [] };
  for (const entry of Object.values(typed.keys || {})) kb.option[entry.base] = entry;
  const moon = keyboard.board === "moonlander" && keyboard.moonlander;
  if (moon) {
    kb.moon = true;
    kb.names = moon.names || [];
    kb.keys = moon.keys.map((geometry, index) => {
      const layers = moon.layers.map((codes) => qmkKey(codes[index] || "KC_NO"));
      for (const entry of layers) if (entry.hold !== undefined && !entry.legend) entry.legend = kb.names[entry.hold] || "Layer " + entry.hold;
      return { ...geometry, layers, base: layers[0] };
    });
  } else {
    kb.moon = false;
    kb.keys = builtinKeys(typed);
  }
  kb.cols = Math.max(...kb.keys.map((key) => key.x + key.w));
  kb.rows = Math.max(...kb.keys.map((key) => key.y + key.h));
  kb.bindings = collectBindings(groups);
  kb.byCombo = {};
  kb.byKey = {};
  kb.used = {}; // without tmux's built-ins, as in the list, or ⌃Z would be on almost every key
  for (const binding of kb.bindings) {
    ((kb.byCombo[binding.combo] ||= {})[binding.key] ||= []).push(binding);
    (kb.byKey[binding.key] ||= []).push(binding);
    if (!binding.folded) (kb.used[binding.key] ||= []).push(binding);
  }
  kb.busiest = Math.max(1, ...Object.values(kb.used).map((list) => list.length));
  for (const byKey of Object.values(kb.byCombo)) {
    for (const list of Object.values(byKey)) list.sort((a, b) => RANK[a.source] - RANK[b.source] || a.shifted - b.shifted);
  }
  const counts = {};
  for (const binding of uniqueRows(kb.bindings)) counts[binding.combo] = (counts[binding.combo] || 0) + 1;
  kb.combos = Object.keys(counts).sort((a, b) => comboOrder(a) - comboOrder(b) || counts[b] - counts[a]).map((id) => ({ id, count: counts[id] }));

  // It opens with no combination picked: each key lists the combinations that do something on it
  Object.assign(pick, { combo: null, peek: null, armed: false, layer: 0, hover: null, row: null });

  modChips.replaceChildren(...kb.combos.map(({ id, count }) => {
    const chip = node("span", "chip", comboLabel(id));
    chip.append(node("span", "n", String(count)));
    chip.dataset.combo = id;
    // Clicking the picked chip again goes back to no combination
    chip.addEventListener("click", () => {
      Object.assign(pick, { combo: pick.combo === id && !pick.layer ? null : id, layer: 0 });
      paintBoard(true);
    });
    return chip;
  }));
  layerChips.hidden = !kb.moon;
  layerChips.replaceChildren(...(kb.moon ? kb.keys[0].layers : []).map((_, layer) => {
    const chip = node("span", "chip", kb.names[layer] || "Layer " + layer);
    chip.dataset.layer = layer;
    chip.addEventListener("click", () => { pick.layer = layer; paintBoard(true); });
    return chip;
  }));
  board.replaceChildren(...kb.keys.map((key, index) => {
    key.element = node("div", "k");
    key.element.append(node("span", "lg"), node("span", "act"));
    key.element.addEventListener("mouseenter", () => { pick.hover = index; paintDetails(); fitSoon(); });
    key.element.addEventListener("mouseleave", () => { pick.hover = null; paintDetails(); fitSoon(); });
    return key.element;
  }));
  const sources = [...new Set(kb.bindings.map((binding) => binding.source))].sort((a, b) => RANK[a] - RANK[b]);
  boardKey.replaceChildren(
    ...sources.map((source) => { const item = node("span", "s-" + source); item.append(node("b"), source === "app" ? appTitle : SOURCE_NAMES[source]); return item; }),
    // The marks' entries show only while a key has that mark (see paintKeys)
    ...[["!", "skhd or Hammerspoon takes it from the app"], ["×", "two global shortcuts on one key"], ["•", "an accent key (⌥E for é) a shortcut has taken"]]
      .map(([mark, text]) => { const item = node("span"); item.dataset.mark = mark; item.append(node("i", null, mark), " " + text); return item; }),
  );
}

// The key unit, from the widest the window can get
function layoutBoard() {
  const u = Math.max(40, Math.min(58, Math.floor((full.width - 2 * BOARD_PADDING - 2) / kb.cols)));
  kb.width = kb.cols * u;
  board.style.setProperty("--u", u + "px");
  board.style.width = kb.width + "px";
  board.style.height = kb.rows * u + "px";
  const gap = Math.max(3, Math.round(u * 0.07));
  for (const key of kb.keys) {
    Object.assign(key.element.style, {
      left: key.x * u + gap / 2 + "px", top: key.y * u + gap / 2 + "px", width: key.w * u - gap + "px", height: key.h * u - gap + "px",
    });
  }
}

const currentCombo = () => pick.peek || pick.combo;
const matching = (query) => kb.bindings.filter((binding) => matchesQuery(query, binding.haystack, [binding]));

// The keys to light for a combination: the Moonlander's Hyper key stands for all four
function litMods(combo) {
  if (combo === "prefix") return new Set(kb.prefix.mods);
  const mods = combo ? combo.split("+") : [];
  if (mods.includes("hyper")) {
    const hyperKey = kb.keys.some((key) => key.base.mod === "hyper");
    mods.splice(mods.indexOf("hyper"), 1, ...(hyperKey ? ["hyper"] : MODS));
  }
  return new Set(mods);
}

function optionChar(combo, char) {
  const entry = kb.option[char];
  return (entry && (combo === "alt" ? entry.alt : combo === "alt+shift" ? entry.altShift : "")) || null;
}

const marksShown = new Set();
function mark(element, text, title) {
  const span = node("span", "mark", text);
  span.title = title;
  element.append(span);
  marksShown.add(text);
}

function paintKeys() {
  const combo = currentCombo(), query = parseQuery(input.value);
  const hits = query.empty ? null : matching(query);
  marksShown.clear();
  const layer = kb.moon && !hits ? pick.layer : 0;
  const lit = hits || layer ? new Set() : litMods(combo);
  for (const chip of modChips.children) {
    chip.classList.toggle("on", !hits && !layer && !pick.peek && chip.dataset.combo === pick.combo);
    chip.classList.toggle("peek", chip.dataset.combo === pick.peek);
  }
  for (const chip of layerChips.children) chip.classList.toggle("on", !hits && +chip.dataset.layer === layer);
  freeChip.classList.toggle("on", pick.free);

  kb.keys.forEach((key) => {
    const { element, base } = key, char = base.char;
    element.className = "k";
    element.querySelector(".mark")?.remove();
    const legend = element.querySelector(".lg");
    legend.textContent = base.legend;
    let parts = [];
    if (base.mod && lit.has(base.mod)) element.classList.add("lit");
    if (!hits && !layer && combo === "prefix" && char === kb.prefix.key) element.classList.add("seq");

    if (layer) {
      const entry = key.layers[layer];
      if (base.hold === layer) {
        element.classList.add("lit");
        parts = [["small", "hold"]];
      } else if (entry.trans) {
        element.classList.add("trans");
      } else if (entry.blank) {
        element.classList.add("dim");
        legend.textContent = "";
      } else {
        legend.textContent = "";
        parts = [[[...entry.legend].length <= 2 ? "big" : "small", entry.legend]];
      }
    } else if (hits) {
      const mine = char ? hits.filter((binding) => binding.key === char) : [];
      if (mine.length) {
        // The first match's label, and the matching combinations as pills, as on the keys with nothing typed
        element.classList.add("hit", "bound", "s-" + mine[0].source);
        const text = capText(mine[0]);
        const combos = [...new Set(mine.map((binding) => (binding.combo === "prefix" ? kb.prefix.text : comboLabel(binding.combo))))];
        const pills = combos.slice(0, 2);
        if (combos.length > 2) pills.push("+" + (combos.length - 2));
        parts = [["big", text.big], ["small", text.small], ["pills", pills]];
      } else {
        element.classList.add("dim");
      }
    } else if (!combo) {
      const used = (char && kb.used[char]) || [];
      if (used.length) {
        // Shaded by how many shortcuts the key has, with the first three combinations as pills
        element.classList.add("used");
        element.style.setProperty("--heat", (used.length / kb.busiest).toFixed(2));
        const combos = [...new Set(used.map((binding) => binding.combo))].sort((a, b) => comboOrder(a) - comboOrder(b));
        const pills = combos.slice(0, 3).map((id) => (id === "prefix" ? kb.prefix.text : comboLabel(id)));
        if (combos.length > 3) pills.push("+" + (combos.length - 3));
        parts = [["pills", pills]];
      } else if (pick.free && char) {
        element.classList.add("free");
        parts = [["small", "free"]];
      }
    } else {
      const list = (char && kb.byCombo[combo]?.[char]) || [];
      const option = char && optionChar(combo, char);
      if (list.length) {
        const text = capText(list[0]);
        element.classList.add("bound", "s-" + list[0].source);
        parts = [["big", text.big], ["small", text.small]];
        if (list[1]) {
          const second = capText(list[1]);
          parts.push(["small second", (second.big ? second.big + " " : "") + second.small]);
        }
        const global = list.filter((binding) => GLOBAL.has(binding.source)), local = list.filter((binding) => LOCAL.has(binding.source));
        const system = list.filter((binding) => binding.source === "mac");
        if (global.length && local.length) mark(element, "!", "Taken from " + local.map((binding) => binding.label).join(", "));
        else if (global.length + system.length > 1) mark(element, "×", list.map((binding) => binding.label).join(" and "));
        else if (option === "dead") mark(element, "•", "Typing accents with this key stops working");
      } else if (option === "dead") {
        element.classList.add("dead");
        parts = [["small", "accent key"]];
      } else if (option) {
        element.classList.add("faint");
        parts = [["big", option]];
      }
      if (pick.free && char && !list.length) {
        element.classList.add("free");
        if (!parts.length) parts = [["small", "free"]];
      }
    }
    const act = element.querySelector(".act");
    act.replaceChildren(...parts.filter(([, text]) => text && text.length).map(([className, text]) => {
      if (className !== "pills") return node("span", className, text);
      const pills = node("span", "pills");
      pills.append(...text.map((pill) => node("span", "pill", pill)));
      return pills;
    }));
  });
  for (const item of boardKey.querySelectorAll("[data-mark]")) item.hidden = !marksShown.has(item.dataset.mark);
  paintRow();
}

// Pointing at a row in the list lights its key and modifiers. Only when the mouse really moves: as you
// type, the list changes under a resting mouse, and WebKit reports the row now under it as entered.
let mouseMoved = false, lastMouse = null;
document.addEventListener("mousemove", (event) => {
  mouseMoved = !lastMouse || lastMouse.x !== event.screenX || lastMouse.y !== event.screenY;
  lastMouse = { x: event.screenX, y: event.screenY };
}, true);

function paintRow() {
  const binding = pick.row === null ? null : kb.bindings[pick.row];
  if (!binding) return;
  const mods = litMods(binding.combo);
  for (const key of kb.keys) {
    key.element.classList.toggle("ping", key.base.char === binding.key);
    key.element.classList.toggle("lit", !!key.base.mod && mods.has(key.base.mod));
    key.element.classList.toggle("seq", binding.combo === "prefix" && key.base.char === kb.prefix.key);
  }
}

function detailRow(binding, text) {
  const item = node("li");
  item.append(node("span", "label", binding.label));
  const keys = item.appendChild(node("span", "keys"));
  if (binding.combo === "prefix") keys.append(node("kbd", null, kb.prefix.text), " ");
  keys.append(node("kbd", null, text || binding.shown));
  item.addEventListener("mousemove", () => {
    if (!mouseMoved || pick.row === binding.id) return;
    pick.row = binding.id;
    paintRow();
  });
  item.addEventListener("mouseleave", () => {
    if (pick.row === null) return;
    pick.row = null;
    paintKeys();
  });
  return item;
}
function noteRow(text, warn) {
  const item = node("li", "note");
  item.append(node("span", "label", text), node("span", "keys"));
  if (warn) item.firstChild.style.color = "var(--warn)";
  return item;
}
// One row per shortcut, not per key: ⌥1–9 stays one row
function uniqueRows(bindings) {
  const seen = new Set();
  return bindings.filter((binding) => {
    const id = binding.source + binding.combo + binding.label + binding.shown;
    return !seen.has(id) && seen.add(id);
  });
}

// Shortcuts under the same headings as in the list, in the list's order, as groups the list's
// layout (measureGroups, flow, part) can lay out
function groupedRows(bindings, perKey) {
  const groups = new Map();
  for (const binding of uniqueRows([...bindings].sort((a, b) => a.id - b.id))) {
    if (!groups.has(binding.groupIndex)) groups.set(binding.groupIndex, []);
    groups.get(binding.groupIndex).push(binding);
  }
  return [...groups.keys()].sort((a, b) => a - b).map((index) => {
    const bindingsHere = groups.get(index), first = bindingsHere[0];
    const head = node("div", "head");
    head.append(node("h3", null, first.groupTitle));
    if (first.tag) head.append(node("span", "tag", first.tag));
    return { className: "group src-" + first.source, head, rows: bindingsHere.map((binding) => detailRow(binding, perKey && binding.text)), more: null };
  });
}

function noteGroup(title, notes) {
  const head = node("div", "head");
  head.append(node("h3", null, title));
  return { className: "group", head, rows: notes, more: null };
}

// A row with a name and a value in a key chip, like "Code  [" for what a key is on another layer
function pairRow(name, value) {
  const item = node("li", "note");
  item.append(node("span", "label", name));
  item.appendChild(node("span", "keys")).append(node("kbd", null, value));
  return item;
}

// Lays the groups out in columns like the list's, as many as fit under the keyboard and widened to fill
// its width. A longer list scrolls rather than making the window wider.
function layOutDetails(groups) {
  const columns = node("div", "columns");
  details.append(columns);
  const perColumn = COLUMN_WIDTH + GAP, inside = 2 * BOARD_PADDING + 2;
  const room = Math.max(minWidth, kb.width + inside) - inside;
  const count = Math.max(1, Math.floor((room + GAP) / perColumn));
  columns.style.setProperty("--extra", Math.max(0, (room - (count * perColumn - GAP)) / count) + "px");
  if (!groups.length) return;
  const measured = measureGroups(groups);
  // Groups too short to split well (see pack) stay whole, even if that leaves a column empty
  const whole = Math.max(0, ...measured.filter(({ rows: groupRows }) => groupRows.length < 2 * MIN_PART)
    .map(({ head, rows: groupRows }) => head + groupRows.reduce((sum, row) => sum + row.height, 0)));
  columns.replaceChildren(...flow(measured, count, whole).map((parts) => {
    const column = node("div", "column");
    column.append(...parts.map(({ group, rows: items, continued }) => part(group, items.map(({ row }) => row), continued)));
    return column;
  }));
  measure.replaceChildren();
}

function paintDetails() {
  // The rows are rebuilt, so the one pointed at is gone, along with the mouse leaving it
  if (pick.row !== null) {
    pick.row = null;
    paintKeys();
  }
  const combo = currentCombo(), query = parseQuery(input.value), index = pick.hover;
  const parts = [], groups = [];
  const heading = (title, sub) => {
    if (title) parts.push(node("h3", null, title));
    if (sub) parts.push(node("p", "sub", sub));
  };
  if (!query.empty) {
    const hits = matching(query);
    const count = uniqueRows(hits).length;
    heading(count + (count === 1 ? " shortcut on the keyboard" : " shortcuts on the keyboard"));
    groups.push(...groupedRows(hits));
  } else if (index !== null && kb.keys[index]) {
    const key = kb.keys[index], char = key.base.char;
    const bindings = (char && kb.byKey[char]) || [];
    heading("Key " + (key.base.legend || ""));
    // Every combination on the key, as on its cap, then its shortcuts grouped as in the list
    const combos = [...new Set(bindings.map((binding) => binding.combo))].sort((a, b) => comboOrder(a) - comboOrder(b));
    if (combos.length) {
      const line = node("p", "combos");
      line.append(...combos.map((id) => node("kbd", null, comboLabel(id))));
      parts.push(line);
    }
    groups.push(...groupedRows(bindings, true));
    // What Option types on the key: characters, not shortcuts
    const typing = [];
    for (const id of char ? ["alt", "alt+shift"] : []) {
      const option = optionChar(id, char);
      const taken = !!kb.byCombo[id]?.[char];
      if (option) typing.push(noteRow(comboLabel(id) + key.base.legend + (option === "dead" ? " is an accent key (é, ü, î…)" : " types " + option), option === "dead" && taken));
    }
    if (typing.length) groups.push(noteGroup("Typing", typing));
    if (kb.moon) {
      groups.push(noteGroup("On the other layers", key.layers.slice(1).map((entry, offset) =>
        pairRow(kb.names[offset + 1] || "Layer " + (offset + 1), entry.trans ? "same" : entry.blank ? "none" : entry.legend))));
    }
    if (!bindings.length && !typing.length && !kb.moon) groups.push(noteGroup("Nothing on this key", []));
  } else if (kb.moon && pick.layer) {
    heading((kb.names[pick.layer] || "Layer " + pick.layer) + " layer",
      "Held with the lit key. Faded keys do what they do on " + (kb.names[0] || "the first layer") + ".");
  } else if (combo) {
    const all = Object.values(kb.byCombo[combo] || {}).flat();
    const count = uniqueRows(all).length;
    heading(comboLabel(combo) + " · " + count + (count === 1 ? " shortcut" : " shortcuts"),
      combo === "prefix" ? "Press " + kb.prefix.text + ", let go, then the key."
        : combo.includes("hyper") ? (kb.keys.some((key) => key.base.mod === "hyper") ? "Hyper is the lit key." : "Hyper is ⌃⌥⇧⌘ held together.")
        : "");
    groups.push(...groupedRows(all));
  } else {
    heading("", "Hold modifiers down, or pick a combination above, to see what the keys do with it.");
    groups.push(...groupedRows(kb.bindings.filter((binding) => !binding.folded)));
  }
  details.replaceChildren(...parts);
  details.scrollTop = 0;
  layOutDetails(groups);
}

// Pointing at keys fits the window to what's listed once the pointer settles, so passing over keys on
// the way to another doesn't make the bottom edge jump
let fitTimer = null;
function fitSoon() {
  clearTimeout(fitTimer);
  fitTimer = setTimeout(() => {
    if (view !== "board") return;
    const size = boardSize();
    window.webkit?.messageHandlers?.shortcuts?.postMessage(size);
  }, 120);
}

// Repaints, and with `resize` has Hammerspoon fit the window to what's now listed
function paintBoard(resize) {
  if (!kb) return;
  paintKeys();
  paintDetails();
  if (resize && view === "board") {
    const size = boardSize();
    window.webkit?.messageHandlers?.shortcuts?.postMessage(size);
  }
}

// The window's size for the keyboard view: as wide as the keyboard, with room for the scroll bar and a gap
// before it, and as tall as everything in it, up to the most the screen allows (the list scrolls past that).
// The top edge stays put.
function boardSize() {
  const inside = 2 * BOARD_PADDING + 2;
  const width = Math.ceil(Math.min(full.width, Math.max(minWidth, kb.width + inside) + SCROLLBAR + BOARD_GUTTER));
  boardView.style.width = width - 2 + "px";
  const height = Math.ceil(details.lastElementChild.getBoundingClientRect().bottom + BOARD_BOTTOM + 1);
  boardView.style.width = "";
  return { width, height, anchor: "top" };
}

function showBoard() {
  main.hidden = true;
  boardView.hidden = false;
  layoutBoard();
  paintBoard();
  return boardSize();
}

function setView(next) {
  view = next;
  viewHint.textContent = view === "board" ? "⇥ list" : "⇥ keyboard";
  if (view === "board") {
    const size = showBoard();
    return window.webkit?.messageHandlers?.shortcuts?.postMessage(size);
  }
  boardView.hidden = true;
  main.hidden = false;
  filterList();
  refresh(true);
}

freeChip.addEventListener("click", () => { pick.free = !pick.free; paintBoard(); });

// Holding modifiers down shows that combination. Modifiers still held from the shortcut that opened
// the overlay count only once one is pressed again.
function onModifier(event) {
  if (view !== "board" || !kb || !["Shift", "Control", "Alt", "Meta"].includes(event.key)) return;
  if (event.type === "keydown") pick.armed = true;
  if (!pick.armed) return;
  const mods = new Set(MODS.filter((mod) => event[{ ctrl: "ctrlKey", alt: "altKey", shift: "shiftKey", cmd: "metaKey" }[mod]]));
  const held = mods.size ? comboId(mods) : null;
  const peek = held && kb.combos.some(({ id }) => id === held) ? held : null;
  if (peek !== pick.peek) {
    pick.peek = peek;
    if (peek) pick.layer = 0;
    paintBoard(true);
  }
}
addEventListener("keydown", onModifier);
addEventListener("keyup", onModifier);

window.webkit?.messageHandlers?.shortcuts?.postMessage("ready");
]==]

local PAGE = table.concat({
    '<!doctype html><html><head><meta charset="utf-8"><style>', CSS, '</style></head><body><div class="panel"><header>',
    -- No spelling, autocorrection or inline predictions: they run on every keystroke, and Tab accepts a prediction
    '<img alt="" hidden><h1></h1><input placeholder="Filter: a word, keys (shift cmd p), or yabai, tmux, macOS…" spellcheck="false"',
    ' autocomplete="off" autocorrect="off" autocapitalize="off" writingsuggestions="false">',
    '<span class="hint view-hint">⇥ keyboard</span><span class="hint">esc</span></header><main>',
    '<section class="area app" data-area="app"><h2></h2><div class="columns"></div></section>',
    '<section class="area everywhere" data-area="everywhere"><h2>Everywhere</h2><div class="columns"></div></section>',
    '<p class="empty" hidden>No shortcuts match</p></main>',
    '<div class="board-view" hidden><div class="board-bar"><div class="chips mods"></div><div class="chips layers"></div>',
    '<span class="chip free">Free keys</span></div><div class="board"></div><div class="board-key"></div>',
    '<div class="board-details"></div></div>',
    '</div><script>', SCRIPT, "</script></body></html>",
})

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

-- What render() gets: the app's name and icon, the groups (without mergeRows' bookkeeping), and the
-- keyboard to draw. The page matches the filter against the rows' descriptions and keys itself.
local function pageData(app)
    local groups = groupsFor(app)
    for _, group in ipairs(groups) do
        for _, row in ipairs(group.rows) do row.seen = nil end
    end
    return { app = app:name(), icon = iconURL(app:bundleID()) or "", groups = groups, keyboard = keyboardData() }
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

-- Grows or shrinks the open window with its content (filtering, unfolding, switching views), keeping it centred
local function fit(size)
    if not M.visible then return end
    local frame = M.view:frame()
    local fitted = centred(size.width or frame.w, size.height or frame.h)
    -- The keyboard view keeps its top edge, so the keyboard stays put while the list under it changes
    if size.anchor == "top" then
        fitted.y = math.max(M.area.y, math.min(frame.y, M.area.y + M.area.h - fitted.h))
    end
    M.view:frame(fitted)
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
        readTypedKeys()
        prewarm()
    end)
end

return M
