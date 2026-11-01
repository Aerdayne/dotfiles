#!/usr/bin/env bash
# Removes the black bar macOS sometimes leaves behind the menu bar on the MacBook screen.
#
# The bar is WindowServer's notch shield ("Display Safe Area Inset Shield"). It blacks out the strip
# beside the camera while an app hides the menu bar (borderless "windowed fullscreen" modes, presentations)
# and normally goes away with that app. Sometimes it stays behind, stuck to one desktop with the menu bar
# back on top, and nothing short of destroying that desktop or restarting removes it. Run by yabai on space
# and display events: when that happens, the desktop is swapped for a fresh one with the same windows
# (recreate-space.sh). Each fix is logged to $LOG, to find out what leaves it behind.
# Usage: fix-notch-shield.sh <event name>

LOG="$HOME/.local/state/yabai/notch-shield.log"
LOCK="/tmp/yabai_${USER}_notch_shield.lock"
GAVE_UP="/tmp/yabai_${USER}_notch_shield.gave-up"
MISSION_CONTROL="/tmp/yabai_${USER}_mission_control.pid" # see refresh-moved-spaces.sh

[ -e "$GAVE_UP" ] && exit 0
mkdir "$LOCK" 2> /dev/null || exit 0 # a check is already running
trap 'rmdir "$LOCK"' EXIT
sleep 1 # let full-screen, display and Mission Control transitions settle
[ -e "$MISSION_CONTROL" ] && exit 0

# Prints the desktop with the stuck shield on the MacBook screen, as yabai space JSON. Scripts run by yabai
# can't read most window names (no Screen Recording permission), so the shield is recognised by its shape:
# a WindowServer window below the normal ones, spanning the top of the built-in screen, as tall as the
# notch. It's only stuck while the menu bar is showing; while an app hides the menu bar it belongs there.
shield_desktop() {
    local origin x y display
    origin="$(osascript -l JavaScript << 'EOF'
ObjC.import("AppKit");
ObjC.import("CoreGraphics");
(() => {
    const screen = $.NSScreen.screens.js.find(
        (screen) => $.CGDisplayIsBuiltin(screen.deviceDescription.objectForKey("NSScreenNumber").js));
    if (!screen || screen.safeAreaInsets.top === 0) return "";
    const bounds = $.CGDisplayBounds(screen.deviceDescription.objectForKey("NSScreenNumber").js);
    const atTop = (frame) => frame.X === bounds.origin.x && frame.Y === bounds.origin.y && frame.Width === bounds.size.width;
    const windows = ObjC.deepUnwrap(ObjC.castRefToObject(
        $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, $.kCGNullWindowID)));
    const shield = windows.some(({ kCGWindowOwnerName: owner, kCGWindowLayer: layer, kCGWindowBounds: frame }) =>
        owner === "Window Server" && layer < 0 && atTop(frame) && frame.Height === screen.safeAreaInsets.top);
    const menuBar = windows.some((window) => window.kCGWindowName === "Menubar" && atTop(window.kCGWindowBounds));
    return shield && menuBar ? `${bounds.origin.x} ${bounds.origin.y}` : "";
})();
EOF
    )"
    [ -n "$origin" ] || return 1
    read -r x y <<< "$origin"
    display="$(yabai -m query --displays | jq --argjson x "$x" --argjson y "$y" '.[] | select(.frame.x == $x and .frame.y == $y) | .index')"
    [ -n "$display" ] || return 1
    # A shield next to a full-screen app is where it belongs
    yabai -m query --spaces --display "$display" | jq -ec '.[] | select(."is-visible" and (."is-native-fullscreen" | not))'
}

desktop="$(shield_desktop)" || exit 0
index="$(jq .index <<< "$desktop")"
mkdir -p "$(dirname "$LOG")"
echo "$(date '+%F %T') $1: black bar on desktop $index ($(yabai -m query --displays | jq length) displays), replacing it" >> "$LOG"
"$HOME/.config/yabai/recreate-space.sh" "$index"

sleep 1
if shield_desktop > /dev/null; then
    echo "$(date '+%F %T') still there after replacing the desktop, leaving it until restart" >> "$LOG"
    touch "$GAVE_UP"
    osascript -e 'display notification "Restart to clear the black bar on the MacBook screen" with title "yabai: could not remove black bar"'
fi
