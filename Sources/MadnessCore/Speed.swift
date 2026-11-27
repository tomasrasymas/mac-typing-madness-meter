// Speed tiers and how strongly the effects show. One tier drives every color
// (meter, window border, tint) so they always agree.

import Foundation

public struct RGB: Equatable {
    public var r: Double, g: Double, b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    /// "#rrggbb" -> RGB (0...255 channels); nil when malformed.
    public init?(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let n = Int(s, radix: 16) else { return nil }
        self.init(Double((n >> 16) & 255), Double((n >> 8) & 255), Double(n & 255))
    }
}

public enum Speed {
    /// Minimum WPM for tiers 1...5 (green, yellow, orange, red, insane).
    public static var tierWpm = [25, 45, 65, 85, 110]
    public static var tierColors = ["#5fd787", "#ffd75f", "#ff8700", "#ff3030", "#ff2bd6"].compactMap { RGB(hex: $0) }
    /// The top tier: the whole screen catches fire.
    public static let insaneTier = 5

    /// Speed colors switch off this long after the last key...
    public static var colorIdleMs: Double = 6000
    /// ...and the tint eases out over the last stretch of that.
    public static var tintFadeMs: Double = 2500
    public static var tintFadeDelayMs: Double { colorIdleMs - tintFadeMs }

    static let hysteresisWpm = 4

    /// Color for a tier; nil for tier 0 ("not fast yet").
    public static func color(_ tier: Int) -> RGB? {
        tier >= 1 && tier <= tierColors.count ? tierColors[tier - 1] : nil
    }

    /// Tier for a WPM with no hysteresis.
    public static func tierIndex(_ wpm: Int) -> Int {
        tierWpm.lastIndex(where: { wpm >= $0 }).map { $0 + 1 } ?? 0
    }

    /// Tier for a WPM, dropping a tier only once WPM falls 4 below its floor.
    public static func tierFor(_ wpm: Int, current: Int) -> Int {
        let tier = tierIndex(wpm)
        if tier < current && current >= 1 && wpm >= tierWpm[current - 1] - hysteresisWpm { return current }
        return tier
    }

    /// The one tier every effect shows: follows speed, 0 once idle long enough.
    public static func speedTier(wpm: Int, idleMs: Double, current: Int) -> Int {
        idleMs > colorIdleMs ? 0 : tierFor(wpm, current: current)
    }

    /// 1 while typing, easing smoothly to 0 by the time the colors switch off.
    public static func idleFade(_ idleMs: Double) -> Double {
        if idleMs <= tintFadeDelayMs { return 1 }
        let x = min(1, (idleMs - tintFadeDelayMs) / tintFadeMs)
        return 1 - x * x * (3 - 2 * x)
    }

    /// Effect strength 0...1: typing burst or sustained speed, whichever is
    /// higher. Full strength from the red tier up.
    public static func intensity(wpm: Int, heat: Double) -> Double {
        let red = tierWpm.count >= 4 ? tierWpm[3] : (tierWpm.last ?? 85)
        return min(1, max(heat, Double(wpm) / Double(red)))
    }
}
