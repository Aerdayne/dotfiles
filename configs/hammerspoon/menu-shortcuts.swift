// Prints the keyboard shortcuts in an app's menu bar as JSON, for shortcuts.lua.
// Hammerspoon's getMenuItems reads every attribute of every menu item one request at a time, which
// takes seconds for a browser's history and bookmarks menus. This reads only what a shortcut needs,
// with one request per item. shortcuts.lua compiles it; it runs with Hammerspoon's Accessibility
// permission because Hammerspoon starts it.
//
// Usage: menu-shortcuts <pid>
//        menu-shortcuts icon <SF Symbol name> <output.png>   (renders the menu bar icon)
//        menu-shortcuts keys                                 (what the keyboard layout types, for the keyboard view)

import AppKit
import ApplicationServices
import Carbon
import IOKit

struct Shortcut: Encodable {
    let menu: String
    let path: [String]
    let title: String
    let char: String
    let glyph: Int
    let modifiers: Int
}

let itemAttributes = [
    kAXTitleAttribute, kAXMenuItemCmdCharAttribute, kAXMenuItemCmdGlyphAttribute,
    kAXMenuItemCmdModifiersAttribute, kAXChildrenAttribute,
] as CFArray

func children(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
    return value as? [AXUIElement] ?? []
}

// Walks a menu's items; a submenu is the single AXMenu child of its item
func walk(_ menu: AXUIElement, _ top: String, _ path: [String], into shortcuts: inout [Shortcut]) {
    for item in children(menu) {
        var result: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(item, itemAttributes, AXCopyMultipleAttributeOptions(), &result) == .success,
              let values = result as? [AnyObject], values.count == 5 else { continue }
        let title = values[0] as? String ?? ""
        let char = values[1] as? String ?? ""
        let glyph = values[2] as? Int ?? 0
        if !title.isEmpty, !char.isEmpty || glyph != 0 {
            shortcuts.append(Shortcut(menu: top, path: path, title: title, char: char, glyph: glyph, modifiers: values[3] as? Int ?? 0))
        }
        if !title.isEmpty, let submenu = (values[4] as? [AXUIElement])?.first {
            walk(submenu, top, path + [title], into: &shortcuts)
        }
    }
}

func printShortcuts(pid: pid_t) {
    var menuBar: CFTypeRef?
    let app = AXUIElementCreateApplication(pid)
    guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar) == .success else { exit(1) }
    var shortcuts: [Shortcut] = []
    for top in children(menuBar as! AXUIElement) {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(top, kAXTitleAttribute as CFString, &title)
        if let menu = children(top).first {
            walk(menu, title as? String ?? "", [], into: &shortcuts)
        }
    }
    FileHandle.standardOutput.write(try! JSONEncoder().encode(shortcuts))
}

// Renders an SF Symbol as a template PNG, at the size of the other menu bar icons
func renderIcon(symbol: String, to path: String) {
    let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration),
          let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * 2), pixelsHigh: Int(image.size.height * 2),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
    bitmap.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try! png.write(to: URL(fileURLWithPath: path))
}

// The built-in keyboard's shape: 0 ANSI, 1 ISO, 2 JIS
func builtInKeyboardType() -> Int {
    var services: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleHIDKeyboardEventDriverV2"), &services) == KERN_SUCCESS else { return 0 }
    defer { IOObjectRelease(services) }
    while case let service = IOIteratorNext(services), service != 0 {
        defer { IOObjectRelease(service) }
        func property(_ name: String) -> Any? { IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
        if (property("Product") as? String)?.hasPrefix("Apple Internal Keyboard") == true { return property("StandardType") as? Int ?? 0 }
    }
    return 0
}

// What the ASCII keyboard layout (ABC, say) types on each key of the built-in keyboard, alone and with
// ⌥ and ⌥⇧, by key code; "dead" marks an accent key, such as ⌥E for é
func printKeys() {
    let shape = builtInKeyboardType()
    guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
          let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { exit(1) }
    let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
    let layout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
    let keyboardType = UInt32([40, 41, 42][min(max(shape, 0), 2)]) // Apple's ANSI, ISO and JIS keyboard types
    func output(_ code: UInt16, _ modifiers: Int) -> String? {
        var deadKeys: UInt32 = 0, length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), UInt32((modifiers >> 8) & 0xFF), keyboardType,
                                    0, &deadKeys, chars.count, &length, &chars)
        if status != noErr { return nil }
        if deadKeys != 0 { return "dead" }
        return length > 0 ? String(utf16CodeUnits: chars, count: length) : nil
    }
    var keys: [String: [String: String]] = [:]
    for code in UInt16(0)...UInt16(50) {
        guard let base = output(code, 0), let scalar = base.unicodeScalars.first, scalar.value > 32 else { continue }
        keys[String(code)] = ["base": base, "alt": output(code, optionKey) ?? "", "altShift": output(code, optionKey | shiftKey) ?? ""]
    }
    let result: [String: Any] = ["shape": ["ANSI", "ISO", "JIS"][min(max(shape, 0), 2)], "keys": keys]
    FileHandle.standardOutput.write(try! JSONSerialization.data(withJSONObject: result))
}

let arguments = CommandLine.arguments
if arguments.count == 4, arguments[1] == "icon" {
    renderIcon(symbol: arguments[2], to: arguments[3])
} else if arguments.count == 2, arguments[1] == "keys" {
    printKeys()
} else if arguments.count == 2, let pid = pid_t(arguments[1]) {
    printShortcuts(pid: pid)
} else {
    FileHandle.standardError.write("usage: menu-shortcuts <pid> | menu-shortcuts icon <symbol> <output.png> | menu-shortcuts keys\n".data(using: .utf8)!)
    exit(2)
}
