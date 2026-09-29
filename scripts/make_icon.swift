// Draws the 2×2 LEGO-brick app icon and writes an .iconset folder for iconutil.
// Usage: swift scripts/make_icon.swift OUT.iconset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS icon grid: the tile is inset ~10% with a ~22% corner radius.
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    let red = NSColor(red: 0.86, green: 0.12, blue: 0.12, alpha: 1)
    let deep = NSColor(red: 0.62, green: 0.05, blue: 0.06, alpha: 1)
    NSGradient(colors: [red, deep])!.draw(in: path, angle: -90)

    let stud = tile.width * 0.27
    let gap = tile.width * 0.11
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

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
