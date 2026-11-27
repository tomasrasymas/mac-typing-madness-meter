// The Insane tier: the whole screen catches fire and laser beams shoot across
// it. Flames burn in from all four edges and blast out of the corners,
// flickering and flaring up, while flamethrowers pop up at random spots on the
// edges and sweep jets of fire across the screen. A transparent,
// click-through window over the screen you're typing on.

import AppKit

final class InsaneFX {
    private let window: NSWindow
    private let root: CALayer
    private let glow = CAGradientLayer()
    private let topGlow = CAGradientLayer()

    /// Where a fire emitter sits and which way its flames go.
    private enum Spot: CaseIterable {
        case bottom, top, left, right, bottomLeft, bottomRight, topLeft, topRight

        var isCorner: Bool { ![.bottom, .top, .left, .right].contains(self) }

        /// Direction the flames shoot, into the screen.
        var angle: CGFloat {
            switch self {
            case .bottom: return .pi / 2
            case .top: return -.pi / 2
            case .left: return .pi / 6
            case .right: return .pi * 5 / 6
            case .bottomLeft: return .pi / 4
            case .bottomRight: return .pi * 3 / 4
            case .topLeft: return -.pi / 4
            case .topRight: return -.pi * 3 / 4
            }
        }

        /// Share of the Fire amount this emitter gets.
        var share: Float {
            switch self {
            case .bottom: return 1
            case .top: return 0.7
            case .left, .right: return 0.6
            default: return 0.35
            }
        }
    }
    private var fires: [(spot: Spot, layer: CAEmitterLayer)] = []
    /// Per-emitter flicker (wanders around 1) and flare-up (jumps, then decays).
    private var flicker: [Float] = []
    private var flare: [Float] = []

    /// A flamethrower: a jet of fire from a spot on an edge, sweeping as it fires.
    private struct Gun {
        let layer: CAEmitterLayer
        var angle: CGFloat
        let sweep: CGFloat // radians per second
        let ends: Double
    }
    private var guns: [Gun] = []
    private var gunCredit = 0.0
    /// Flame speed that reaches `insaneFireHeight` of the screen.
    private var reach: CGFloat = 300
    private var screenFrame: NSRect = .zero
    private var placedHeight = -1.0

    /// 0...1: eases in when you hit Insane, out when you drop below.
    private var level: CGFloat = 0
    private var laserCredit = 0.0
    private var lastActive = 0.0
    private var settings = Tuning()

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

        glow.colors = [
            NSColor(srgbRed: 1, green: 0.2, blue: 0.05, alpha: 0.55).cgColor,
            NSColor(srgbRed: 1, green: 0.5, blue: 0.05, alpha: 0.18).cgColor,
            NSColor(srgbRed: 1, green: 0.5, blue: 0.05, alpha: 0).cgColor,
        ]
        glow.locations = [0, 0.45, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0)
        glow.opacity = 0
        root.addSublayer(glow)
        topGlow.colors = glow.colors
        topGlow.locations = glow.locations
        topGlow.startPoint = CGPoint(x: 0.5, y: 1)
        topGlow.opacity = 0
        root.addSublayer(topGlow)

        for spot in Spot.allCases {
            let emitter = CAEmitterLayer()
            emitter.emitterShape = spot.isCorner ? .point : .line
            // Normal blending keeps flames orange and red on light pages too;
            // additive would wash them out to white there.
            emitter.renderMode = .unordered
            emitter.birthRate = 0
            var cells = [InsaneFX.flame(corner: spot.isCorner), InsaneFX.flameCore()]
            if spot == .bottom { cells.append(InsaneFX.ember()) }
            emitter.emitterCells = cells
            root.addSublayer(emitter)
            fires.append((spot, emitter))
        }
        flicker = Array(repeating: 1, count: fires.count)
        flare = Array(repeating: 0, count: fires.count)
    }

    /// Call every frame. `active` is true while you're at the Insane tier.
    func update(active: Bool, screen: NSScreen?, now t: Double, tuning: Tuning) {
        settings = tuning
        if active {
            lastActive = t
        }
        let fireOn = active && tuning.insaneFire
        level = fireOn ? min(1, level + 0.08) : max(0, level - 0.03)

        // Nothing on screen and nothing still flying: hide the window.
        if !active && level == 0 && t - lastActive > 2500 {
            if window.isVisible { window.orderOut(nil) }
            return
        }
        if let screen, screen.frame != screenFrame || tuning.insaneFireHeight != placedHeight { place(on: screen) }
        if !window.isVisible, active { window.orderFrontRegardless() }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.opacity = Float(level)
        topGlow.opacity = Float(level * 0.8)
        let rate = fireOn ? Float(tuning.insaneFireAmount) : 0
        for (i, (spot, emitter)) in fires.enumerated() {
            // Flicker: wander between about half and one and a half.
            flicker[i] = flicker[i] * 0.85 + Float.random(in: 0.4...1.6) * 0.15
            // Flare-up: now and then an edge or corner suddenly roars.
            if Float.random(in: 0...1) < 0.012 { flare[i] = 1 }
            flare[i] *= 0.9
            emitter.birthRate = rate * spot.share * (flicker[i] + flare[i] * 2)
        }
        updateGuns(fireOn: fireOn, now: t)
        CATransaction.commit()

        if active && tuning.insaneLasers {
            laserCredit += tuning.insaneLasersPerSecond / 30
            while laserCredit >= 1 {
                laserCredit -= 1
                shootLaser()
            }
        } else {
            laserCredit = 0
        }
    }

    private func place(on screen: NSScreen) {
        screenFrame = screen.frame
        placedHeight = settings.insaneFireHeight
        window.setFrame(screenFrame, display: false)
        let b = NSRect(origin: .zero, size: screenFrame.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = b
        glow.frame = b
        glow.endPoint = CGPoint(x: 0.5, y: min(1, settings.insaneFireHeight * 1.4))
        topGlow.frame = b
        topGlow.endPoint = CGPoint(x: 0.5, y: max(0, 1 - settings.insaneFireHeight))

        // Flames burn in from every edge and blast out of every corner. They
        // live long enough to reach `insaneFireHeight` of the screen from the
        // bottom; the other edges reach a bit less.
        let lifetime: CGFloat = 1.5
        reach = b.height * CGFloat(settings.insaneFireHeight) / lifetime
        for (spot, emitter) in fires {
            emitter.frame = b
            switch spot {
            case .bottom:
                emitter.emitterPosition = CGPoint(x: b.midX, y: b.minY - 10)
                emitter.emitterSize = CGSize(width: b.width * 1.05, height: 0)
            case .top:
                emitter.emitterPosition = CGPoint(x: b.midX, y: b.maxY + 10)
                emitter.emitterSize = CGSize(width: b.width * 1.05, height: 0)
            case .left:
                emitter.emitterPosition = CGPoint(x: b.minX - 10, y: b.midY)
                emitter.emitterSize = CGSize(width: 0, height: b.height)
            case .right:
                emitter.emitterPosition = CGPoint(x: b.maxX + 10, y: b.midY)
                emitter.emitterSize = CGSize(width: 0, height: b.height)
            case .bottomLeft: emitter.emitterPosition = CGPoint(x: b.minX, y: b.minY)
            case .bottomRight: emitter.emitterPosition = CGPoint(x: b.maxX, y: b.minY)
            case .topLeft: emitter.emitterPosition = CGPoint(x: b.minX, y: b.maxY)
            case .topRight: emitter.emitterPosition = CGPoint(x: b.maxX, y: b.maxY)
            }
            let speed = spot == .bottom ? reach : spot.isCorner ? reach * 1.1 : reach * 0.75
            emitter.setValue(speed, forKeyPath: "emitterCells.flame.velocity")
            emitter.setValue(speed * 0.45, forKeyPath: "emitterCells.flame.velocityRange")
            emitter.setValue(speed * 0.6, forKeyPath: "emitterCells.core.velocity")
            emitter.setValue(speed * 1.6, forKeyPath: "emitterCells.ember.velocity")
            emitter.setValue(spot.angle, forKeyPath: "emitterCells.flame.emissionLongitude")
            emitter.setValue(spot.angle, forKeyPath: "emitterCells.core.emissionLongitude")
            // Top and side flames burn out sooner, so they stay near their edge
            // instead of leaving sparks across the middle of the screen.
            if spot != .bottom {
                emitter.setValue(1.0, forKeyPath: "emitterCells.flame.lifetime")
                emitter.setValue(0.2, forKeyPath: "emitterCells.flame.lifetimeRange")
                emitter.setValue(-0.95, forKeyPath: "emitterCells.flame.alphaSpeed")
                emitter.setValue(-1.4, forKeyPath: "emitterCells.flame.scaleSpeed")
            }
        }
        CATransaction.commit()
    }

    // MARK: Flamethrowers

    private func updateGuns(fireOn: Bool, now t: Double) {
        if fireOn && settings.insaneGunsPerSecond > 0 {
            gunCredit += settings.insaneGunsPerSecond / 30
            while gunCredit >= 1 {
                gunCredit -= 1
                spawnGun(now: t)
            }
        } else {
            gunCredit = 0
        }
        // Sweep each jet, and shut it off when its time is up (or the fire stops).
        guns = guns.filter { gun in
            if !fireOn || t >= gun.ends {
                gun.layer.birthRate = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { gun.layer.removeFromSuperlayer() }
                return false
            }
            return true
        }
        for i in guns.indices {
            guns[i].angle += guns[i].sweep / 30
            guns[i].layer.setValue(guns[i].angle, forKeyPath: "emitterCells.jet.emissionLongitude")
            guns[i].layer.setValue(guns[i].angle, forKeyPath: "emitterCells.jetCore.emissionLongitude")
        }
    }

    /// A new flamethrower at a random spot on an edge, aimed roughly inward.
    private func spawnGun(now t: Double) {
        let b = root.bounds
        guard b.width > 0 else { return }
        let side = Int.random(in: 0..<4)
        let along = CGFloat.random(in: 0.08...0.92)
        let (point, inward): (CGPoint, CGFloat) = {
            switch side {
            case 0: return (CGPoint(x: b.width * along, y: b.minY - 6), .pi / 2)
            case 1: return (CGPoint(x: b.maxX + 6, y: b.height * along), .pi)
            case 2: return (CGPoint(x: b.width * along, y: b.maxY + 6), -.pi / 2)
            default: return (CGPoint(x: b.minX - 6, y: b.height * along), 0)
            }
        }()
        let power = CGFloat(settings.insaneGunPower)
        let emitter = CAEmitterLayer()
        emitter.frame = b
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .unordered
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = [InsaneFX.jet(speed: reach * 2.4 * power), InsaneFX.jetCore(speed: reach * 2 * power)]
        root.addSublayer(emitter)

        let angle = inward + .random(in: -0.5...0.5)
        let sweep = CGFloat.random(in: 0.4...1.0) * (Bool.random() ? 1 : -1)
        let gun = Gun(layer: emitter, angle: angle, sweep: sweep, ends: t + .random(in: 600...1300))
        emitter.setValue(angle, forKeyPath: "emitterCells.jet.emissionLongitude")
        emitter.setValue(angle, forKeyPath: "emitterCells.jetCore.emissionLongitude")
        guns.append(gun)
    }

    /// The flamethrower's fire: a tight, fast stream that billows out as it flies.
    private static func jet(speed: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "jet"
        c.contents = Overlay.dotImage
        c.color = NSColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 1).cgColor
        c.greenSpeed = -0.65 // yellow, then orange, then red at the tip
        c.blueSpeed = -0.5
        c.birthRate = 260
        c.lifetime = 0.8
        c.lifetimeRange = 0.25
        c.velocity = speed
        c.velocityRange = speed * 0.2
        c.emissionRange = 0.12
        c.yAcceleration = 120 // hot air rises
        c.scale = 0.5
        c.scaleRange = 0.2
        c.scaleSpeed = 0.9 // billows out
        c.alphaSpeed = -1.25
        return c
    }

    /// The white-hot nozzle end of the jet.
    private static func jetCore(speed: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "jetCore"
        c.contents = Overlay.dotImage
        c.color = NSColor(srgbRed: 1, green: 0.97, blue: 0.8, alpha: 1).cgColor
        c.greenSpeed = -1.2
        c.blueSpeed = -1.4
        c.birthRate = 140
        c.lifetime = 0.35
        c.velocity = speed
        c.velocityRange = speed * 0.15
        c.emissionRange = 0.08
        c.scale = 0.5
        c.scaleSpeed = 1.2
        c.alphaSpeed = -2.2
        return c
    }

    // MARK: Lasers

    /// A neon beam from one edge of the screen to another, with a spark burst
    /// where it hits. It draws in fast, glows, then fades.
    private func shootLaser() {
        let b = root.bounds
        guard b.width > 0 else { return }
        let fromSide = Int.random(in: 0..<4)
        let from = edgePoint(fromSide, b)
        let to = edgePoint((fromSide + Int.random(in: 1...3)) % 4, b)
        let color = Overlay.palette.randomElement()!
        let width = CGFloat(settings.insaneLaserWidth)

        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let group = CALayer()
        group.frame = b
        let beam = CAShapeLayer()
        beam.path = path
        beam.strokeColor = color.cgColor
        beam.lineWidth = width
        beam.lineCap = .round
        beam.shadowColor = color.cgColor
        beam.shadowRadius = width * 3
        beam.shadowOpacity = 1
        beam.shadowOffset = .zero
        let core = CAShapeLayer()
        core.path = path
        // A pale core in the beam's own color reads on light pages as well as dark.
        core.strokeColor = (color.blended(withFraction: 0.55, of: .white) ?? .white).cgColor
        core.lineWidth = max(1, width * 0.4)
        core.lineCap = .round
        group.addSublayer(beam)
        group.addSublayer(core)
        root.addSublayer(group)

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.12
        beam.add(draw, forKey: "draw")
        core.add(draw, forKey: "draw")
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.35, 1]
        fade.duration = 0.55
        group.opacity = 0
        group.add(fade, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.sparks(at: to, color: color) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { group.removeFromSuperlayer() }
    }

    /// A random point on side 0 bottom, 1 right, 2 top, 3 left.
    private func edgePoint(_ side: Int, _ b: CGRect) -> CGPoint {
        switch side {
        case 0: return CGPoint(x: .random(in: b.minX...b.maxX), y: b.minY)
        case 1: return CGPoint(x: b.maxX, y: .random(in: b.minY...b.maxY))
        case 2: return CGPoint(x: .random(in: b.minX...b.maxX), y: b.maxY)
        default: return CGPoint(x: b.minX, y: .random(in: b.minY...b.maxY))
        }
    }

    private func sparks(at point: CGPoint, color: NSColor) {
        let e = CAEmitterLayer()
        e.frame = root.bounds
        e.emitterPosition = point
        e.emitterShape = .point
        e.renderMode = .additive
        e.beginTime = CACurrentMediaTime()
        let c = CAEmitterCell()
        c.contents = Overlay.dotImage
        c.color = color.cgColor
        c.birthRate = 1200
        c.lifetime = 0.6
        c.velocity = 260
        c.velocityRange = 120
        c.emissionRange = .pi * 2
        c.scale = 0.15
        c.scaleSpeed = -0.2
        c.alphaSpeed = -1.6
        e.emitterCells = [c]
        root.addSublayer(e)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { e.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { e.removeFromSuperlayer() }
    }

    // MARK: Particles

    /// A fire blob: starts yellow-white, burns to red and smoke as it rises.
    /// Corner jets spray wider and burn bigger than the edge flames.
    private static func flame(corner: Bool) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "flame"
        c.contents = Overlay.dotImage
        c.color = NSColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 1).cgColor
        c.greenSpeed = -0.75
        c.blueSpeed = -0.4
        // Times the emitter's birthRate (the Fire amount setting).
        c.birthRate = corner ? 260 : 420
        c.lifetime = 1.5
        c.lifetimeRange = 0.4
        c.velocity = 300 // set from the screen height in place(on:)
        c.velocityRange = 130
        c.emissionLongitude = .pi / 2 // set per edge or corner in place(on:)
        c.emissionRange = corner ? 0.7 : 0.3
        c.yAcceleration = 90 // hot air rises
        c.scale = corner ? 2.1 : 1.8
        c.scaleRange = 0.7
        c.scaleSpeed = -0.9
        c.alphaSpeed = -0.7
        return c
    }

    /// The bright base of the fire: a dense, low, white-hot band.
    private static func flameCore() -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "core"
        c.contents = Overlay.dotImage
        c.color = NSColor(srgbRed: 1, green: 0.95, blue: 0.7, alpha: 1).cgColor
        c.greenSpeed = -0.9
        c.blueSpeed = -0.9
        c.birthRate = 300
        c.lifetime = 0.8
        c.lifetimeRange = 0.3
        c.velocity = 150 // set from the screen height in place(on:)
        c.velocityRange = 60
        c.emissionLongitude = .pi / 2
        c.emissionRange = 0.2
        c.scale = 1.2
        c.scaleRange = 0.4
        c.scaleSpeed = -1.0
        c.alphaSpeed = -1.1
        return c
    }

    /// Small bright embers that fly higher than the flames.
    private static func ember() -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "ember"
        c.contents = Overlay.dotImage
        c.color = NSColor(srgbRed: 1, green: 0.75, blue: 0.3, alpha: 1).cgColor
        c.birthRate = 25
        c.lifetime = 2
        c.velocity = 450
        c.velocityRange = 200
        c.emissionLongitude = .pi / 2
        c.emissionRange = 0.5
        c.scale = 0.12
        c.scaleRange = 0.06
        c.alphaSpeed = -0.5
        return c
    }
}
