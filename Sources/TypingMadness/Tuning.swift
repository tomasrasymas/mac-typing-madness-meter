// Every adjustable number and color, kept in UserDefaults. The Settings window
// edits them; the app reloads them whenever they change.

import AppKit
import MadnessCore

struct Tuning {
    /// UserDefaults keys, shared with the Settings window.
    enum Key {
        static let tierWpm = ["tier1Wpm", "tier2Wpm", "tier3Wpm", "tier4Wpm", "tier5Wpm"]
        static let tierColor = ["tier1Color", "tier2Color", "tier3Color", "tier4Color", "tier5Color"]
        static let tintStrength = "tintStrength"
        static let glowWidth = "glowWidth"
        static let holdSeconds = "holdSeconds"
        static let fadeSeconds = "fadeSeconds"

        static let comboMilestone = "comboMilestone"
        static let flashStrength = "flashStrength"
        static let badgeSeconds = "badgeSeconds"

        static let fireworksAchievement = "fireworksAchievement"
        static let fireworksLevel = "fireworksLevel"
        static let fireworksRecord = "fireworksRecord"
        static let fireworksCombo = "fireworksCombo"
        static let fireworksComboEvery = "fireworksComboEvery"
        static let fireworkSize = "fireworkSize"
        static let fastEffectsFrom = "fastEffectsFrom"
        static let fastEffectsAmount = "fastEffectsAmount"
        static let starsPerJump = "starsPerJump"
        static let starHeight = "starHeight"
        static let starSize = "starSize"

        static let shakeFrom = "shakeFrom"
        static let shakeStrength = "shakeStrength"
        static let milestoneShake = "milestoneShake"
        static let maxShake = "maxShake"
        static let badgeShake = "badgeShake"
        static let meterShake = "meterShake"

        static let meterOpacity = "meterOpacity"
        static let meterBackground = "meterBackground"
        static let meterPosition = "meterPosition"
        static let meterOnWindow = "meterOnWindow"
        static let meterScreenSpot = "meterScreenSpot"
        static let meterWindowSpot = "meterWindowSpot"
        static let meterLocked = "meterLocked"
        static let meterLayout = "meterLayout"
        static let meterSize = "meterSize"

        static let insaneFire = "insaneFire"
        static let insaneFireAmount = "insaneFireAmount"
        static let insaneFireHeight = "insaneFireHeight"
        static let insaneGunsPerSecond = "insaneGunsPerSecond"
        static let insaneGunPower = "insaneGunPower"
        static let insaneLasers = "insaneLasers"
        static let insaneLasersPerSecond = "insaneLasersPerSecond"
        static let insaneLaserWidth = "insaneLaserWidth"

        static let comboGapSeconds = "comboGapSeconds"
        static let comboStep = "comboStep"
        static let maxMultiplier = "maxMultiplier"
    }

    // Speed and colors
    var tierWpm = [25, 45, 65, 85, 110]
    var tierColors = ["#5fd787", "#ffd75f", "#ff8700", "#ff3030", "#ff2bd6"]
    /// Strongest window tint, 0...1.
    var tintStrength = 0.22
    /// Glowing border width, points.
    var glowWidth = 4.0
    /// Colors hold this long after the last key, then fade over `fadeSeconds`.
    var holdSeconds = 3.5
    var fadeSeconds = 2.5

    // Milestones
    var comboMilestone = 25
    /// Flash brightness, 0...1. Big milestones add a little.
    var flashStrength = 0.5
    /// Small badge time; big ones stay a second longer.
    var badgeSeconds = 1.6

    // Fireworks and stars
    var fireworksAchievement = 16
    var fireworksLevel = 8
    var fireworksRecord = 8
    var fireworksCombo = 3
    var fireworksComboEvery = 100
    var fireworkSize = 1.0
    /// Speed tier where fast-typing stars and fireworks start (2 yellow … 5 insane, 9 never).
    var fastEffectsFrom = 2
    var fastEffectsAmount = 1.0
    var starsPerJump = 3
    /// How high stars jump, as a share of the window height.
    var starHeight = 0.4
    var starSize = 1.0

    // Window shake
    /// Speed tier where the window starts shaking (9 never).
    var shakeFrom = 3
    /// Shake at the top speed tier, points; half that one tier lower.
    var shakeStrength = 4.0
    var milestoneShake = 1.0
    var maxShake = 9.0
    /// Multipliers for the milestone badge and floating meter shakes.
    var badgeShake = 1.0
    var meterShake = 1.0

    // Floating meter
    /// The whole meter, text included, 0...1.
    var meterOpacity = 1.0
    /// Just the dark background behind the text, 0...1.
    var meterBackground = 0.86
    var meterPosition = MeterPosition.bottomCenter
    /// Docked to the window you're typing in, instead of the screen's edge.
    var meterOnWindow = false
    /// Where the user dragged the meter: a screen point, or an offset from the
    /// docked window's top-left corner. nil means use `meterPosition`.
    var meterScreenSpot: CGPoint?
    var meterWindowSpot: CGPoint?
    /// Locked: click-through and can't be dragged or resized.
    var meterLocked = false
    var meterLayout = MeterLayout.auto
    /// The size the user dragged the meter to; nil means the layout's natural size.
    var meterSize: CGSize?

    // Insane tier: whole-screen fire and lasers
    var insaneFire = true
    /// Fire particles, ×1 = default.
    var insaneFireAmount = 1.0
    /// How far up the screen the flames reach, 0...1.
    var insaneFireHeight = 0.35
    /// Flamethrowers that pop up at random spots on the edges; 0 turns them off.
    var insaneGunsPerSecond = 1.5
    var insaneGunPower = 1.0
    var insaneLasers = true
    var insaneLasersPerSecond = 6.0
    var insaneLaserWidth = 6.0

    // Game rules
    var comboGapSeconds = 1.2
    var comboStep = 25
    var maxMultiplier = 5.0

    static let defaults = Tuning()

    init() {}

    init(_ d: UserDefaults) {
        let b = Tuning.defaults
        func int(_ k: String, _ v: Int) -> Int { d.object(forKey: k) == nil ? v : d.integer(forKey: k) }
        func dbl(_ k: String, _ v: Double) -> Double { d.object(forKey: k) == nil ? v : d.double(forKey: k) }
        func str(_ k: String, _ v: String) -> String { d.string(forKey: k) ?? v }

        tierWpm = zip(Key.tierWpm, b.tierWpm).map { int($0, $1) }
        tierColors = zip(Key.tierColor, b.tierColors).map { str($0, $1) }
        tintStrength = dbl(Key.tintStrength, b.tintStrength)
        glowWidth = dbl(Key.glowWidth, b.glowWidth)
        holdSeconds = dbl(Key.holdSeconds, b.holdSeconds)
        fadeSeconds = dbl(Key.fadeSeconds, b.fadeSeconds)
        comboMilestone = int(Key.comboMilestone, b.comboMilestone)
        flashStrength = dbl(Key.flashStrength, b.flashStrength)
        badgeSeconds = dbl(Key.badgeSeconds, b.badgeSeconds)
        fireworksAchievement = int(Key.fireworksAchievement, b.fireworksAchievement)
        fireworksLevel = int(Key.fireworksLevel, b.fireworksLevel)
        fireworksRecord = int(Key.fireworksRecord, b.fireworksRecord)
        fireworksCombo = int(Key.fireworksCombo, b.fireworksCombo)
        fireworksComboEvery = int(Key.fireworksComboEvery, b.fireworksComboEvery)
        fireworkSize = dbl(Key.fireworkSize, b.fireworkSize)
        fastEffectsFrom = int(Key.fastEffectsFrom, b.fastEffectsFrom)
        fastEffectsAmount = dbl(Key.fastEffectsAmount, b.fastEffectsAmount)
        starsPerJump = int(Key.starsPerJump, b.starsPerJump)
        starHeight = dbl(Key.starHeight, b.starHeight)
        starSize = dbl(Key.starSize, b.starSize)
        shakeFrom = int(Key.shakeFrom, b.shakeFrom)
        shakeStrength = dbl(Key.shakeStrength, b.shakeStrength)
        milestoneShake = dbl(Key.milestoneShake, b.milestoneShake)
        maxShake = dbl(Key.maxShake, b.maxShake)
        badgeShake = dbl(Key.badgeShake, b.badgeShake)
        meterShake = dbl(Key.meterShake, b.meterShake)
        meterOpacity = dbl(Key.meterOpacity, b.meterOpacity)
        meterBackground = dbl(Key.meterBackground, b.meterBackground)
        meterPosition = MeterPosition(rawValue: str(Key.meterPosition, b.meterPosition.rawValue)) ?? b.meterPosition
        meterOnWindow = d.object(forKey: Key.meterOnWindow) == nil ? b.meterOnWindow : d.bool(forKey: Key.meterOnWindow)
        func point(_ k: String) -> CGPoint? {
            guard let a = d.array(forKey: k) as? [Double], a.count == 2 else { return nil }
            return CGPoint(x: a[0], y: a[1])
        }
        meterScreenSpot = point(Key.meterScreenSpot)
        meterWindowSpot = point(Key.meterWindowSpot)
        meterLocked = d.bool(forKey: Key.meterLocked)
        meterLayout = MeterLayout(rawValue: str(Key.meterLayout, b.meterLayout.rawValue)) ?? b.meterLayout
        meterSize = point(Key.meterSize).map { CGSize(width: max(60, $0.x), height: max(20, $0.y)) }
        func bool(_ k: String, _ v: Bool) -> Bool { d.object(forKey: k) == nil ? v : d.bool(forKey: k) }
        insaneFire = bool(Key.insaneFire, b.insaneFire)
        insaneFireAmount = dbl(Key.insaneFireAmount, b.insaneFireAmount)
        insaneFireHeight = dbl(Key.insaneFireHeight, b.insaneFireHeight)
        insaneGunsPerSecond = dbl(Key.insaneGunsPerSecond, b.insaneGunsPerSecond)
        insaneGunPower = dbl(Key.insaneGunPower, b.insaneGunPower)
        insaneLasers = bool(Key.insaneLasers, b.insaneLasers)
        insaneLasersPerSecond = dbl(Key.insaneLasersPerSecond, b.insaneLasersPerSecond)
        insaneLaserWidth = dbl(Key.insaneLaserWidth, b.insaneLaserWidth)
        comboGapSeconds = dbl(Key.comboGapSeconds, b.comboGapSeconds)
        comboStep = int(Key.comboStep, b.comboStep)
        maxMultiplier = dbl(Key.maxMultiplier, b.maxMultiplier)
    }

    static var allKeys: [String] {
        Key.tierWpm + Key.tierColor + [
            Key.tintStrength, Key.glowWidth, Key.holdSeconds, Key.fadeSeconds,
            Key.comboMilestone, Key.flashStrength, Key.badgeSeconds,
            Key.fireworksAchievement, Key.fireworksLevel, Key.fireworksRecord, Key.fireworksCombo,
            Key.fireworksComboEvery, Key.fireworkSize, Key.fastEffectsFrom, Key.fastEffectsAmount,
            Key.starsPerJump, Key.starHeight, Key.starSize,
            Key.shakeFrom, Key.shakeStrength, Key.milestoneShake, Key.maxShake, Key.badgeShake, Key.meterShake,
            Key.meterOpacity, Key.meterBackground, Key.meterPosition, Key.meterOnWindow,
            Key.meterScreenSpot, Key.meterWindowSpot, Key.meterLocked, Key.meterLayout, Key.meterSize,
            Key.insaneFireAmount, Key.insaneFireHeight, Key.insaneGunsPerSecond, Key.insaneGunPower,
            Key.insaneLasersPerSecond, Key.insaneLaserWidth,
            Key.comboGapSeconds, Key.comboStep, Key.maxMultiplier,
        ]
    }

    /// Forget where the meter was dragged, so it goes back to its Position.
    static func resetMeterSpot() {
        UserDefaults.standard.removeObject(forKey: Key.meterScreenSpot)
        UserDefaults.standard.removeObject(forKey: Key.meterWindowSpot)
    }

    /// Forget the dragged size, so the meter goes back to its layout's natural size.
    static func resetMeterSize() {
        UserDefaults.standard.removeObject(forKey: Key.meterSize)
    }

    /// Back to the built-in values (on/off switches are left alone).
    static func reset() {
        for key in allKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    /// Push the speed and game settings into MadnessCore.
    func apply(to game: Game) {
        Speed.tierWpm = tierWpm.sorted()
        Speed.tierColors = tierColors.enumerated().map { i, hex in
            RGB(hex: hex) ?? RGB(hex: Tuning.defaults.tierColors[i])!
        }
        Speed.colorIdleMs = (holdSeconds + fadeSeconds) * 1000
        Speed.tintFadeMs = fadeSeconds * 1000
        game.config.comboMilestone = max(1, comboMilestone)
        game.config.comboGapMs = comboGapSeconds * 1000
        game.config.comboStep = max(1, comboStep)
        game.config.maxMultiplier = maxMultiplier
    }
}

/// Where the floating meter sits, on the screen or the window it's docked to.
enum MeterPosition: String, CaseIterable {
    case topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight

    var title: String {
        switch self {
        case .topLeft: return "Top left"
        case .topCenter: return "Top center"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomCenter: return "Bottom center"
        case .bottomRight: return "Bottom right"
        }
    }

    var isTop: Bool { [.topLeft, .topCenter, .topRight].contains(self) }
    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
    var isRight: Bool { self == .topRight || self == .bottomRight }
}

/// The meter's layout. Auto picks one from the meter's shape as you resize it.
enum MeterLayout: String, CaseIterable {
    case auto, singleLine, wide, square

    var title: String {
        switch self {
        case .auto: return "Fit to shape"
        case .singleLine: return "Single line"
        case .wide: return "Two lines"
        case .square: return "Square"
        }
    }

    /// The forced layout, or nil for Auto.
    var shape: MeterShape? {
        switch self {
        case .auto: return nil
        case .singleLine: return .singleLine
        case .wide: return .wide
        case .square: return .square
        }
    }
}
