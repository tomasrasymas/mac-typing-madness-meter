// A transparent, click-through window kept exactly over the window you're
// typing in. It draws the speed tint, a glowing border, milestone flashes,
// shaking badges, fireworks and stars that jump when you type fast. Clicks and keys pass straight through to the app below.

import AppKit
import MadnessCore

final class Overlay {
    /// The user's settings: tint, glow, flash, badge and star numbers.
    var tuning = Tuning() {
        didSet {
            borderLayer.lineWidth = CGFloat(tuning.glowWidth)
            layoutStars()
        }
    }
    /// Room around the window for the border glow.
    private let pad: CGFloat = 28
    private let cornerRadius: CGFloat = 10

    private let window: NSWindow
    private let root: CALayer
    private let tintLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let flashLayer = CAShapeLayer()
    /// A thick, bright border that pulses on milestones.
    private let ringLayer = CAShapeLayer()
    /// Holds the star emitter and short-lived firework emitters.
    private let fxLayer = CALayer()
    private let starEmitter = CAEmitterLayer()
    private let badgeLayer = CATextLayer()
    private var target: NSRect = .zero
    /// The active window's area inside the overlay.
    private var inner: NSRect = .zero
    private var badgeHide: DispatchWorkItem?

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        window.contentView = view
        root = view.layer!

        for shape in [tintLayer, flashLayer, borderLayer, ringLayer] {
            shape.fillColor = nil
            shape.strokeColor = nil
            root.addSublayer(shape)
        }
        borderLayer.lineWidth = 4
        borderLayer.shadowOffset = .zero
        borderLayer.shadowRadius = 14
        flashLayer.opacity = 0
        ringLayer.opacity = 0
        ringLayer.lineWidth = 6
        ringLayer.shadowOffset = .zero
        ringLayer.shadowRadius = 26
        ringLayer.shadowOpacity = 1

        root.addSublayer(fxLayer)
        starEmitter.emitterShape = .rectangle
        starEmitter.emitterMode = .volume
        starEmitter.renderMode = .additive
        starEmitter.birthRate = 0
        // One cell per color, each morphing into the next color as it flies.
        starEmitter.emitterCells = Overlay.palette.indices.map(Overlay.jumpingStar)
        fxLayer.addSublayer(starEmitter)

        badgeLayer.alignmentMode = .center
        badgeLayer.font = NSFont.systemFont(ofSize: 64, weight: .black)
        badgeLayer.fontSize = 64
        badgeLayer.opacity = 0
        badgeLayer.shadowColor = NSColor.black.cgColor
        badgeLayer.shadowOpacity = 0.6
        badgeLayer.shadowRadius = 8
        badgeLayer.shadowOffset = .zero
        root.addSublayer(badgeLayer)
    }

    /// Call every frame. `frame` nil hides the overlay.
    /// - intensity: how fast you're going (0...1), drives tint and glow strength.
    /// - fade: 1 while typing, easing to 0 after you stop.
    func update(frame: NSRect?, color: RGB?, intensity: Double, fade: Double, tint: Bool, border: Bool) {
        guard let frame else {
            if window.isVisible { window.orderOut(nil) }
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if frame.size != target.size {
            window.setFrame(frame.insetBy(dx: -pad, dy: -pad), display: false)
            layout()
        } else if frame.origin != target.origin {
            // Just moved (or shaking): no need to redo the layers.
            window.setFrameOrigin(NSPoint(x: frame.minX - pad, y: frame.minY - pad))
        }
        target = frame
        let c = color.map(nsColor)
        let tintAlpha = CGFloat(tuning.tintStrength * intensity * fade)
        tintLayer.fillColor = tint && c != nil && tintAlpha > 0.003 ? c!.withAlphaComponent(tintAlpha).cgColor : nil
        if border, let c, fade > 0.003 {
            borderLayer.strokeColor = c.withAlphaComponent(0.95 * CGFloat(fade)).cgColor
            borderLayer.shadowColor = c.cgColor
            borderLayer.shadowOpacity = Float(min(1, 0.4 + intensity) * fade)
        } else {
            borderLayer.strokeColor = nil
            borderLayer.shadowOpacity = 0
        }
        CATransaction.commit()
        if !window.isVisible { window.orderFrontRegardless() }
    }

    /// A full-window flash plus a pulsing border ring. `big` pulses three times
    /// and lasts longer, for level-ups, records and achievements.
    func flash(_ color: NSColor, big: Bool = false) {
        guard window.isVisible else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let strength = big ? min(1, tuning.flashStrength + 0.1) : tuning.flashStrength
        flashLayer.fillColor = color.withAlphaComponent(CGFloat(strength)).cgColor
        ringLayer.strokeColor = color.cgColor
        ringLayer.shadowColor = color.cgColor
        CATransaction.commit()

        let pulses: [Double] = big ? [1, 0.1, 0.9, 0.05, 0.7, 0] : [1, 0.15, 0.6, 0]
        let duration = big ? 1.2 : 0.6
        flashLayer.add(keyframes("opacity", pulses, duration), forKey: "flash")
        ringLayer.add(keyframes("opacity", pulses.map { min(1, $0 * 1.3) }, duration * 1.3), forKey: "flash")
        let width = CABasicAnimation(keyPath: "lineWidth")
        width.fromValue = big ? 22 : 14
        width.toValue = 4
        width.duration = duration * 1.3
        width.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringLayer.add(width, forKey: "width")
    }

    /// `count` firework bursts at random spots in the window, `gap` seconds apart.
    func fireworks(count: Int, colors: [NSColor], power: CGFloat = 1, gap: Double = 0.25) {
        guard window.isVisible, count > 0, !colors.isEmpty else { return }
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * gap) { [weak self] in
                guard let self, self.window.isVisible, self.inner.width > 0 else { return }
                let area = self.inner.insetBy(dx: self.inner.width * 0.15, dy: self.inner.height * 0.15)
                let point = CGPoint(x: .random(in: area.minX...area.maxX),
                                    y: .random(in: area.midY...area.maxY))
                self.burst(at: point, color: colors[i % colors.count], power: power)
            }
        }
    }

    /// Multicolored stars jumping up from the lower half of the window, `rate`
    /// per second. Call every frame; 0 stops new stars (ones in the air finish
    /// their arc).
    func stars(rate: Float) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        starEmitter.birthRate = window.isVisible ? rate : 0
        CATransaction.commit()
    }

    private func burst(at point: CGPoint, color: NSColor, power: CGFloat) {
        let emitter = CAEmitterLayer()
        emitter.frame = fxLayer.bounds
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()

        let spark = CAEmitterCell()
        spark.contents = Overlay.dotImage
        spark.color = color.cgColor
        spark.redRange = 0.15
        spark.greenRange = 0.15
        spark.blueRange = 0.15
        spark.birthRate = Float(2400 * power)
        spark.lifetime = 1.5
        spark.lifetimeRange = 0.4
        spark.velocity = 280 * power
        spark.velocityRange = 70 * power
        spark.emissionRange = .pi * 2
        spark.yAcceleration = -260
        spark.scale = 0.2
        spark.scaleRange = 0.08
        spark.scaleSpeed = -0.1
        spark.alphaSpeed = -0.6

        let glint = CAEmitterCell()
        glint.contents = Overlay.starImage
        glint.color = NSColor.white.cgColor
        glint.birthRate = Float(300 * power)
        glint.lifetime = 1.2
        glint.velocity = 180 * power
        glint.velocityRange = 60
        glint.emissionRange = .pi * 2
        glint.yAcceleration = -200
        glint.spin = 4
        glint.spinRange = 8
        glint.scale = 0.22
        glint.alphaSpeed = -0.8

        emitter.emitterCells = [spark, glint]
        fxLayer.addSublayer(emitter)
        // One short puff of particles, then let them fly out and clean up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { emitter.removeFromSuperlayer() }
    }

    private func keyframes(_ keyPath: String, _ values: [Double], _ duration: Double) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: keyPath)
        anim.values = values
        anim.duration = duration
        anim.calculationMode = .linear
        return anim
    }

    /// Big text in the middle of the window that pops in, shakes, holds, then
    /// fades. `big` pops harder, shakes harder and stays longer.
    func badge(_ text: String, color: NSColor, big: Bool = false) {
        guard window.isVisible else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        badgeLayer.string = text
        badgeLayer.foregroundColor = color.cgColor
        badgeLayer.contentsScale = window.backingScaleFactor
        badgeLayer.opacity = 1
        CATransaction.commit()

        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = big ? [0.3, 1.4, 0.92, 1.1, 1] : [0.6, 1.2, 1]
        pop.duration = big ? 0.6 : 0.3
        badgeLayer.add(pop, forKey: "pop")

        // Shake hard, settling down.
        let shake = CAKeyframeAnimation(keyPath: "position")
        let center = badgeLayer.position
        let maxAmp = (big ? 24 : 14) * CGFloat(tuning.badgeShake)
        shake.values = (0..<12).map { i -> NSValue in
            let amp = maxAmp * (1 - CGFloat(i) / 12)
            return NSValue(point: NSPoint(x: center.x + .random(in: -amp...amp), y: center.y + .random(in: -amp...amp) / 2))
        } + [NSValue(point: center)]
        shake.duration = big ? 0.6 : 0.4
        badgeLayer.add(shake, forKey: "shake")
        let seconds = big ? tuning.badgeSeconds + 1 : tuning.badgeSeconds

        badgeHide?.cancel()
        let hide = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.badgeLayer.opacity = 0 // implicit fade
        }
        badgeHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: hide)
    }

    /// Stars launch from anywhere in the lower half of the window and jump
    /// `starHeight` of the window height (on average), whatever its size.
    private func layoutStars() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        starEmitter.emitterPosition = CGPoint(x: inner.midX, y: inner.minY + inner.height * 0.25)
        starEmitter.emitterSize = CGSize(width: inner.width * 0.9, height: inner.height * 0.5)
        let velocity = (2 * Overlay.starGravity * inner.height * CGFloat(tuning.starHeight)).squareRoot()
        let size = CGFloat(tuning.starSize)
        for cell in starEmitter.emitterCells ?? [] {
            let path = "emitterCells.\(cell.name!)"
            starEmitter.setValue(velocity, forKeyPath: "\(path).velocity")
            starEmitter.setValue(velocity * 0.4, forKeyPath: "\(path).velocityRange")
            starEmitter.setValue(0.32 * size, forKeyPath: "\(path).scale")
            starEmitter.setValue(0.14 * size, forKeyPath: "\(path).scaleRange")
        }
        CATransaction.commit()
    }

    private func layout() {
        let bounds = NSRect(origin: .zero, size: window.frame.size)
        root.frame = bounds
        inner = bounds.insetBy(dx: pad, dy: pad)
        let path = CGPath(roundedRect: inner, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        for shape in [tintLayer, flashLayer] {
            shape.frame = bounds
            shape.path = path
        }
        let edge = inner.insetBy(dx: -2, dy: -2)
        let edgePath = CGPath(roundedRect: edge, cornerWidth: cornerRadius + 2, cornerHeight: cornerRadius + 2, transform: nil)
        for shape in [borderLayer, ringLayer] {
            shape.frame = bounds
            shape.path = edgePath
        }
        fxLayer.frame = bounds
        starEmitter.frame = bounds
        layoutStars()
        let badgeHeight: CGFloat = 84
        badgeLayer.frame = NSRect(x: inner.minX, y: inner.midY - badgeHeight / 2, width: inner.width, height: badgeHeight)
    }
}

// MARK: - Particles

extension Overlay {
    static let starGravity: CGFloat = 700

    /// Colors for stars and fireworks.
    static let palette: [NSColor] = [
        NSColor(srgbRed: 1, green: 0.84, blue: 0.2, alpha: 1),   // gold
        NSColor(srgbRed: 1, green: 0.3, blue: 0.55, alpha: 1),   // pink
        NSColor(srgbRed: 0.72, green: 0.4, blue: 1, alpha: 1),   // purple
        NSColor(srgbRed: 0.3, green: 0.85, blue: 1, alpha: 1),   // cyan
        NSColor(srgbRed: 0.4, green: 1, blue: 0.5, alpha: 1),    // green
        NSColor(srgbRed: 1, green: 0.55, blue: 0.1, alpha: 1),   // orange
    ]

    /// A star that jumps up from the lower half of the window and falls back,
    /// spinning, starting in palette color `index` and shifting to the next.
    static func jumpingStar(_ index: Int) -> CAEmitterCell {
        let lifetime: Float = 2.2
        let from = palette[index], to = palette[(index + 1) % palette.count]
        let cell = CAEmitterCell()
        cell.name = "star\(index)"
        cell.contents = starImage
        cell.color = from.cgColor
        cell.redSpeed = Float(to.redComponent - from.redComponent) / lifetime
        cell.greenSpeed = Float(to.greenComponent - from.greenComponent) / lifetime
        cell.blueSpeed = Float(to.blueComponent - from.blueComponent) / lifetime
        // The emitter's birthRate sets stars per second, split across colors.
        cell.birthRate = 1 / Float(palette.count)
        cell.lifetime = lifetime
        cell.velocity = 520 // set from the window height in layout()
        cell.velocityRange = 200
        cell.emissionLongitude = .pi / 2 // up
        cell.emissionRange = .pi / 5
        cell.yAcceleration = -CGFloat(starGravity)
        cell.spin = 3
        cell.spinRange = 8
        cell.scale = 0.32
        cell.scaleRange = 0.14
        cell.alphaSpeed = -0.45
        return cell
    }

    /// A soft white glow dot, tinted per particle.
    static let dotImage: CGImage = image(size: 64) { ctx, size in
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.5), CGColor(gray: 1, alpha: 0)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.3, 1])!
        let c = CGPoint(x: size / 2, y: size / 2)
        ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size / 2, options: [])
    }

    /// A white five-point star with a glow, tinted per particle.
    static let starImage: CGImage = image(size: 64) { ctx, size in
        let c = CGPoint(x: size / 2, y: size / 2)
        let outer = size * 0.36, innerR = outer * 0.45
        let path = CGMutablePath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : innerR
            let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        ctx.setShadow(offset: .zero, blur: size * 0.12, color: CGColor(gray: 1, alpha: 0.9))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func image(size: Int, draw: (CGContext, CGFloat) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(ctx, CGFloat(size))
        return ctx.makeImage()!
    }
}

func nsColor(_ c: RGB) -> NSColor {
    NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
}
