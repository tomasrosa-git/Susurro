import AppKit

enum MenuBarIcon {
    /// The logo's fading wave as a template image, so macOS tints it for light and dark menu bars.
    static let wave: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let box = bounds.insetBy(dx: 1, dy: 2)
            let path = NSBezierPath()
            let steps = 120
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let envelope = sin(t * .pi)
                let point = CGPoint(x: box.minX + t * box.width, y: box.midY + sin(t * .pi * 4) * envelope * box.height * 0.45)
                i == 0 ? path.move(to: point) : path.line(to: point)
            }
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Susurro"
        return image
    }()
}
