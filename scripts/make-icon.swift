// Draws the app icon and writes Resources/AppIcon.icns. Run with scripts/make-icon.sh.
import AppKit

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

/// Same fading wave as the menu bar glyph (Sources/Susurro/MenuBarIcon.swift).
func wave(in box: CGRect, lineWidth: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let steps = 240
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let envelope = sin(t * .pi)
        let point = CGPoint(x: box.minX + t * box.width, y: box.midY + sin(t * .pi * 4) * envelope * box.height * 0.42)
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    return path
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: an 824/1024 rounded tile centered on the canvas, leaving room for the shadow.
    let size = CGFloat(pixels)
    let tile = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 100 / 1024, dy: size * 100 / 1024)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    shadow.set()
    color(0x0F172A).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: color(0x1E3A8A), ending: color(0x0F172A))!.draw(in: shape, angle: -90)

    let glyph = tile.width * 0.6
    NSColor.white.setStroke()
    wave(
        in: CGRect(x: tile.midX - glyph / 2, y: tile.midY - glyph / 2, width: glyph, height: glyph),
        lineWidth: max(glyph * 0.085, 1.5)
    ).stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}
