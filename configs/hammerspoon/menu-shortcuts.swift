// Prints the keyboard shortcuts in an app's menu bar as JSON, for shortcuts.lua.
// Hammerspoon's getMenuItems reads every attribute of every menu item one request at a time, which
// takes seconds for a browser's history and bookmarks menus. This reads only what a shortcut needs,
// with one request per item. shortcuts.lua compiles it; it runs with Hammerspoon's Accessibility
// permission because Hammerspoon starts it.
//
// Usage: menu-shortcuts <pid>
//        menu-shortcuts icon <SF Symbol name> <output.png>   (renders the menu bar icon)

import AppKit
import ApplicationServices

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

let arguments = CommandLine.arguments
if arguments.count == 4, arguments[1] == "icon" {
    renderIcon(symbol: arguments[2], to: arguments[3])
} else if arguments.count == 2, let pid = pid_t(arguments[1]) {
    printShortcuts(pid: pid)
} else {
    FileHandle.standardError.write("usage: menu-shortcuts <pid> | menu-shortcuts icon <symbol> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
