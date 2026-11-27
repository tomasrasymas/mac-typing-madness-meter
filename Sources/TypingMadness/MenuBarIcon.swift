// The menu-bar icon: a keycap with a "!" and flames on top that grow with
// your speed tier, plus shake marks at the fastest tiers. Idle, it's a plain
// template image like other menu-bar icons; typing, the flames take the
// speed color.

import AppKit
import MadnessCore

enum MenuBarIcon {
    private static var cache: [Int: NSImage] = [:]

    /// The icon for a speed tier (0 = idle).
    static func image(tier: Int) -> NSImage {
        let tier = min(max(tier, 0), 5)
        if let cached = cache[tier] { return cached }
        let flameColor = Speed.color(tier).map(nsColor)
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            draw(tier: tier, flame: flameColor)
            return true
        }
        // Idle: a template, so macOS tints it to match the menu bar.
        image.isTemplate = flameColor == nil
        image.accessibilityDescription = "Typing Madness"
        cache[tier] = image
        return image
    }

    /// Flame height above the key, per tier.
    private static let flameHeight: [CGFloat] = [0, 2.4, 3.4, 4.4, 5.2, 6]

    private static func draw(tier: Int, flame: NSColor?) {
        // Template images only use alpha; colored ones follow the menu bar's look.
        let ink = flame == nil ? NSColor.black : NSColor.labelColor

        // Keycap seen from the front: the outer edge, and the top face set
        // higher inside it, so the key has depth.
        let key = NSRect(x: 4, y: 1, width: 14, height: 11.5)
        ink.setStroke()
        let cap = NSBezierPath(roundedRect: key.insetBy(dx: 0.65, dy: 0.65), xRadius: 3, yRadius: 3)
        cap.lineWidth = 1.3
        cap.stroke()
        let face = NSRect(x: key.minX + 2.3, y: key.minY + 3, width: key.width - 4.6, height: key.height - 4.4)
        let faceOutline = NSBezierPath(roundedRect: face, xRadius: 1.8, yRadius: 1.8)
        faceOutline.lineWidth = 1
        faceOutline.stroke()

        // "!" on the top face.
        ink.setFill()
        let mid = face.midX
        NSBezierPath(roundedRect: NSRect(x: mid - 0.75, y: face.minY + 2.5, width: 1.5, height: 3.4),
                     xRadius: 0.75, yRadius: 0.75).fill()
        NSBezierPath(ovalIn: NSRect(x: mid - 0.75, y: face.minY + 0.7, width: 1.5, height: 1.5)).fill()

        // Flames rising off the top of the key: three tongues, the middle tallest.
        let h = flameHeight[tier]
        if h > 0 {
            (flame ?? ink).setFill()
            let top = key.maxY - 0.5
            for (x, w, scale, lean) in [(7.5, 3.6, 0.7, -0.6), (11, 4.2, 1.0, 0.3), (14.5, 3.6, 0.8, 0.7)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                let tongue = NSBezierPath()
                let th = h * scale
                tongue.move(to: NSPoint(x: x - w / 2, y: top))
                tongue.curve(to: NSPoint(x: x + lean, y: top + th),
                             controlPoint1: NSPoint(x: x - w / 2, y: top + th * 0.5),
                             controlPoint2: NSPoint(x: x + lean - 0.6, y: top + th * 0.8))
                tongue.curve(to: NSPoint(x: x + w / 2, y: top),
                             controlPoint1: NSPoint(x: x + lean + 0.6, y: top + th * 0.6),
                             controlPoint2: NSPoint(x: x + w / 2, y: top + th * 0.4))
                tongue.close()
                tongue.fill()
            }
        }

        // Shake marks either side of the key at orange and red.
        if tier >= 3 {
            (flame ?? ink).setStroke()
            for (x, dir) in [(CGFloat(1.6), CGFloat(-1)), (CGFloat(20.4), CGFloat(1))] {
                let arc = NSBezierPath()
                arc.move(to: NSPoint(x: x, y: 9.5))
                arc.curve(to: NSPoint(x: x, y: 3.5),
                          controlPoint1: NSPoint(x: x + dir * 1.4, y: 8),
                          controlPoint2: NSPoint(x: x + dir * 1.4, y: 5))
                arc.lineWidth = 1.3
                arc.lineCapStyle = .round
                arc.stroke()
            }
        }
    }
}
