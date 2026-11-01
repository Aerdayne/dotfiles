// Lists large windows touching the top 80pt of each display (owner, layer, frame, name).
// Used to identify the black bar on the MacBook screen: "Display Safe Area Inset Shield" (WindowServer).
// It gets stuck on one desktop; fix-notch-shield.sh detects and removes it automatically.
// Run: swift configs/yabai/top-windows.swift
import CoreGraphics
import Foundation

var ids = [CGDirectDisplayID](repeating: 0, count: 8)
var n: UInt32 = 0
CGGetActiveDisplayList(8, &ids, &n)
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
for id in ids.prefix(Int(n)) {
    let b = CGDisplayBounds(id)
    print("display \(id) builtin=\(CGDisplayIsBuiltin(id) != 0) bounds=\(Int(b.minX)),\(Int(b.minY)) \(Int(b.width))x\(Int(b.height))")
    let strip = CGRect(x: b.minX, y: b.minY, width: b.width, height: 80)
    for w in windows {
        guard let d = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
        let r = CGRect(x: d["X"]!, y: d["Y"]!, width: d["Width"]!, height: d["Height"]!)
        guard r.intersects(strip), r.width >= b.width * 0.3 else { continue }
        let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
        let pid = w[kCGWindowOwnerPID as String] as? Int ?? 0
        let layer = w[kCGWindowLayer as String] as? Int ?? 0
        let alpha = w[kCGWindowAlpha as String] as? Double ?? 0
        let wid = w[kCGWindowNumber as String] as? Int ?? 0
        let name = w[kCGWindowName as String] as? String ?? ""
        print("   wid=\(wid) owner=\(owner) pid=\(pid) layer=\(layer) alpha=\(alpha) frame=\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)) name=\"\(name)\"")
    }
}
