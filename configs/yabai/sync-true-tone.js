#!/usr/bin/osascript -l JavaScript

// True Tone tints every connected display, not just the MacBook's, and macOS has no per-display
// switch. Keep it on while the MacBook is used on its own, and off while an external display is
// connected. Run by yabai whenever a display is added or removed (see .yabairc).
// Uses CoreBrightness's private CBTrueToneClient, which backs the toggle in System Settings.

ObjC.import("AppKit");
ObjC.import("CoreGraphics");

function run() {
    $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/CoreBrightness.framework").load;
    const trueTone = $.NSClassFromString("CBTrueToneClient").alloc.init;
    if (!trueTone.supported) return "True Tone not supported";

    const hasExternal = $.NSScreen.screens.js.some(
        (screen) => !$.CGDisplayIsBuiltin(screen.deviceDescription.objectForKey("NSScreenNumber").js)
    );
    const enable = !hasExternal;
    if (trueTone.enabled !== enable) trueTone.setEnabled(enable);
    return `True Tone ${enable ? "on" : "off"} (external display ${hasExternal ? "" : "not "}connected)`;
}
