// Draws the app icon: a keycap with a "!" on fire, in the app's speed colors,
// with shake marks and sparkles. Writes a 1024px PNG.
//
//   swift scripts/make-icon.swift out.png
//
// scripts/make-icon.sh turns it into Resources/AppIcon.icns.

import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

// The speed colors from the app: green, yellow, orange, red.
let green = rgb(0x5fd787), yellow = rgb(0xffd75f), orange = rgb(0xff8700), red = rgb(0xff3030)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func linear(_ colors: [CGColor], _ from: CGPoint, _ to: CGPoint, _ locations: [CGFloat]? = nil) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ colors: [CGColor], _ center: CGPoint, _ radius: CGFloat) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// A flame tongue rising from `base`, `w` wide and `h` tall, its tip leaning by `lean`.
func flame(_ base: CGPoint, _ w: CGFloat, _ h: CGFloat, lean: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let tip = CGPoint(x: base.x + lean, y: base.y + h)
    p.move(to: CGPoint(x: base.x - w / 2, y: base.y))
    p.addCurve(to: tip,
               control1: CGPoint(x: base.x - w * 0.65, y: base.y + h * 0.55),
               control2: CGPoint(x: base.x + lean * 0.2 - w * 0.1, y: base.y + h * 0.75))
    p.addCurve(to: CGPoint(x: base.x + w / 2, y: base.y),
               control1: CGPoint(x: base.x + lean * 0.4 + w * 0.25, y: base.y + h * 0.6),
               control2: CGPoint(x: base.x + w * 0.7, y: base.y + h * 0.3))
    p.addQuadCurve(to: CGPoint(x: base.x - w / 2, y: base.y), control: CGPoint(x: base.x, y: base.y - w * 0.45))
    p.closeSubpath()
    return p
}

/// A four-point sparkle.
func sparkle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let k = r * 0.22
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
    return p
}

// MARK: Background: the standard macOS rounded square, deep night purple.

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: rgb(0x000000, 0.4))
ctx.addPath(tilePath)
ctx.setFillColor(rgb(0x140726))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
linear([rgb(0x3a1470), rgb(0x12052a)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 100))
// Heat glow rising from below the key.
radial([rgb(0xff5a1f, 0.75), rgb(0xff3030, 0.25), rgb(0xff3030, 0)], CGPoint(x: 512, y: 330), 470)

// MARK: Flames behind the key, outer red to inner yellow.

let tongues: [(x: CGFloat, w: CGFloat, h: CGFloat, lean: CGFloat)] = [
    (330, 210, 430, -40), (430, 230, 560, -20), (520, 250, 620, 15), (610, 230, 540, 35), (700, 200, 420, 50),
]
for (layer, color) in [(1.0, red), (0.8, orange), (0.6, yellow)] {
    for t in tongues {
        let base = CGPoint(x: t.x, y: 300 + (1 - layer) * 40)
        ctx.addPath(flame(base, t.w * layer, t.h * layer, lean: t.lean * layer))
        ctx.setFillColor(color)
        ctx.fillPath()
    }
}

// MARK: The keycap.

let side = CGRect(x: 287, y: 190, width: 450, height: 390)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: rgb(0x000000, 0.55))
ctx.addPath(CGPath(roundedRect: side, cornerWidth: 72, cornerHeight: 72, transform: nil))
ctx.setFillColor(rgb(0xb9b6cc))
ctx.fillPath()
ctx.restoreGState()
// Side walls: darker toward the bottom.
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: side, cornerWidth: 72, cornerHeight: 72, transform: nil))
ctx.clip()
linear([rgb(0xd8d5e8), rgb(0x8f8aa8)], CGPoint(x: 512, y: 580), CGPoint(x: 512, y: 190))
ctx.restoreGState()
// Top face, set back and up, slightly dished.
let face = CGRect(x: 327, y: 262, width: 370, height: 300)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: face, cornerWidth: 52, cornerHeight: 52, transform: nil))
ctx.clip()
linear([rgb(0xffffff), rgb(0xe6e3f2)], CGPoint(x: 512, y: 562), CGPoint(x: 512, y: 262))
radial([rgb(0xffffff, 0), rgb(0xcfcbe2, 0.35)], CGPoint(x: 512, y: 412), 260)
ctx.restoreGState()

// The "!" in speed-red.
let bang = NSAttributedString(string: "!", attributes: [
    .font: NSFont.systemFont(ofSize: 280, weight: .black),
    .foregroundColor: NSColor(cgColor: red)!,
])
let bangSize = bang.size()
bang.draw(at: CGPoint(x: 512 - bangSize.width / 2, y: 412 - bangSize.height / 2 + 6))

// MARK: Shake marks either side of the key.

ctx.setLineCap(.round)
ctx.setLineWidth(16)
for (i, alpha) in [(0, 0.95), (1, 0.6)] {
    let offset = CGFloat(i) * 42
    for (cx, dir) in [(CGFloat(250) - offset, CGFloat(-1)), (CGFloat(774) + offset, CGFloat(1))] {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cx, y: 460))
        p.addQuadCurve(to: CGPoint(x: cx, y: 300), control: CGPoint(x: cx + dir * 34, y: 380))
        ctx.addPath(p)
        ctx.setStrokeColor(rgb(0xffffff, CGFloat(alpha)))
        ctx.strokePath()
    }
}

// MARK: Sparkles in the other speed colors.

for (c, r, color) in [
    (CGPoint(x: 232, y: 760), CGFloat(58), yellow),
    (CGPoint(x: 806, y: 790), CGFloat(44), green),
    (CGPoint(x: 205, y: 590), CGFloat(26), rgb(0x4dd8ff)),
    (CGPoint(x: 822, y: 600), CGFloat(30), rgb(0xff4d8c)),
    (CGPoint(x: 512, y: 860), CGFloat(24), rgb(0xffffff)),
] {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24, color: color)
    ctx.addPath(sparkle(c, r))
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

ctx.restoreGState()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
