// Draws the 2×2 LEGO-brick app icon and writes an .iconset folder for iconutil, or with --web
// the PNGs for the web app (icon-192/512 plus a full-bleed maskable-512 for Android).
// Usage: swift scripts/make_icon.swift OUT.iconset
//        swift scripts/make_icon.swift --web OUT_DIR
import AppKit

enum Style { case mac, web, maskable }

let web = CommandLine.arguments[1] == "--web"
let out = URL(fileURLWithPath: CommandLine.arguments[web ? 2 : 1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int, _ style: Style = .mac) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS icon grid: the tile is inset ~10% with a ~22% corner radius. Android crops
    // maskable icons to its own shape, keeping only the central 80% circle.
    let inset: CGFloat = style == .mac ? 0.1 : style == .web ? 0.02 : 0
    let tile = NSRect(x: s * inset, y: s * inset, width: s * (1 - 2 * inset), height: s * (1 - 2 * inset))
    let radius = style == .maskable ? 0 : tile.width * 0.225
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    let red = NSColor(red: 0.86, green: 0.12, blue: 0.12, alpha: 1)
    let deep = NSColor(red: 0.62, green: 0.05, blue: 0.06, alpha: 1)
    NSGradient(colors: [red, deep])!.draw(in: path, angle: -90)

    let span = style == .maskable ? s * 0.62 : tile.width
    let stud = span * 0.27
    let gap = span * 0.11
    let origin = CGPoint(x: tile.midX - stud - gap / 2, y: tile.midY - stud - gap / 2)
    for row in 0..<2 {
        for col in 0..<2 {
            let rect = NSRect(x: origin.x + CGFloat(col) * (stud + gap),
                              y: origin.y + CGFloat(row) * (stud + gap), width: stud, height: stud)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
            shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
            shadow.shadowBlurRadius = s * 0.015
            shadow.set()
            deep.setFill()
            NSBezierPath(ovalIn: rect).fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(colors: [NSColor(red: 1.0, green: 0.36, blue: 0.32, alpha: 1), red])!
                .draw(in: NSBezierPath(ovalIn: rect.insetBy(dx: stud * 0.06, dy: stud * 0.06)), angle: 90)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

if web {
    try render(192, .web).write(to: out.appendingPathComponent("icon-192.png"))
    try render(512, .web).write(to: out.appendingPathComponent("icon-512.png"))
    try render(512, .maskable).write(to: out.appendingPathComponent("maskable-512.png"))
} else {
    for size in [16, 32, 128, 256, 512] {
        try render(size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
        try render(size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}
