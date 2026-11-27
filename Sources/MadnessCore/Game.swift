// Pure typing game engine: no I/O, time is always passed in (milliseconds).
// Ported from the herdr Typing Madness Meter so levels and XP feel the same.

import Foundation

public enum KeyClass: Equatable {
    case char, backspace, enter, other
}

public struct DayStats: Codable, Equatable {
    public var chars = 0
    public var keys = 0
    public var xp = 0
    public var bestWpm = 0
    public var bestCombo = 0
    public init() {}
}

public struct Stats: Codable, Equatable {
    public var version = 1
    public var totalChars = 0
    public var totalKeys = 0
    public var totalXp = 0
    public var bestWpm = 0
    public var bestCombo = 0
    public var days: [String: DayStats] = [:]
    /// Achievement id -> unlock time (ms since epoch).
    public var achievements: [String: Double] = [:]
    public init() {}
}

public enum MilestoneReason: Equatable {
    case combo, level, record
}

public enum GameEvent: Equatable {
    case milestone(MilestoneReason, value: Int)
    case achievement(id: String, title: String, description: String)
    case comboBreak(combo: Int)
}

public struct Live {
    public var wpm: Int
    public var sessionPeakWpm: Int
    public var combo: Int
    public var multiplier: Double
    public var accuracy: Double
    public var level: Int
    public var rank: String
    /// XP earned inside the current level, and the XP the level needs.
    public var levelXp: Int
    public var levelSpan: Int
    /// 0...1 typing intensity: drives shake and sparks.
    public var heat: Double
    public var today: DayStats
    public var idleMs: Double
}

public struct GameConfig {
    /// Max gap between keys before the combo breaks.
    public var comboGapMs: Double = 1200
    /// A combo milestone (flash, badge) fires every this many keys.
    public var comboMilestone = 25
    /// Every this many combo keys add ×0.5 to the XP multiplier.
    public var comboStep = 25
    /// Cap for the XP multiplier.
    public var maxMultiplier: Double = 5
    public init() {}
}

let wpmWindowMs: Double = 10_000
let wpmMinSpanMs: Double = 2_000
/// Chars needed inside the window before a WPM counts toward records.
let wpmQualifyChars = 25
let accuracyWindowSize = 200
let heatPerChar = 0.07
let heatTauMs: Double = 700

public let ranks: [(Int, String)] = [
    (0, "Hunt & Peck"),
    (3, "Home Row Hero"),
    (6, "Keyboard Warrior"),
    (10, "Combo Crusher"),
    (15, "Speed Typist"),
    (22, "Clackmaster"),
    (30, "Keyboard Demon"),
]

/// Total XP required to reach `level`.
public func xpForLevel(_ level: Int) -> Int { 100 * level * level }

public func levelForXp(_ xp: Int) -> Int { Int((Double(max(0, xp)) / 100).squareRoot()) }

public func rankFor(_ level: Int) -> String {
    ranks.last(where: { level >= $0.0 })?.1 ?? ranks[0].1
}

public func multiplierFor(_ combo: Int, step: Int = 25, max maxMultiplier: Double = 5) -> Double {
    min(max(1, maxMultiplier), 1 + Double(combo / max(1, step)) * 0.5)
}

public func dayKey(_ t: Double) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: t / 1000))
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

func hour(_ t: Double) -> Int {
    Calendar.current.component(.hour, from: Date(timeIntervalSince1970: t / 1000))
}

/// Consecutive days (ending today or yesterday) with at least 500 chars.
public func streakDays(_ stats: Stats, _ t: Double) -> Int {
    let cal = Calendar.current
    var day = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date(timeIntervalSince1970: t / 1000))!
    let chars = { (d: Date) in stats.days[dayKey(d.timeIntervalSince1970 * 1000)]?.chars ?? 0 }
    if chars(day) < 500 { day = cal.date(byAdding: .day, value: -1, to: day)! }
    var streak = 0
    while chars(day) >= 500 {
        streak += 1
        day = cal.date(byAdding: .day, value: -1, to: day)!
    }
    return streak
}

public struct Achievement {
    public let id: String
    public let title: String
    public let description: String
    let check: (Game, Double) -> Bool
}

public let achievements: [Achievement] = [
    Achievement(id: "first_steps", title: "First Steps", description: "Type 100 characters") { g, _ in g.stats.totalChars >= 100 },
    Achievement(id: "wpm_60", title: "Cruising", description: "Reach 60 WPM") { g, _ in g.stats.bestWpm >= 60 },
    Achievement(id: "wpm_100", title: "Ton Up", description: "Reach 100 WPM") { g, _ in g.stats.bestWpm >= 100 },
    Achievement(id: "wpm_140", title: "Ludicrous Speed", description: "Reach 140 WPM") { g, _ in g.stats.bestWpm >= 140 },
    Achievement(id: "combo_100", title: "Combo Starter", description: "Hit a 100 combo") { g, _ in g.stats.bestCombo >= 100 },
    Achievement(id: "combo_500", title: "Unbroken", description: "Hit a 500 combo") { g, _ in g.stats.bestCombo >= 500 },
    Achievement(id: "combo_1000", title: "Flow State", description: "Hit a 1000 combo") { g, _ in g.stats.bestCombo >= 1000 },
    Achievement(id: "day_10k", title: "Marathon", description: "Type 10,000 characters in one day") { g, t in
        (g.stats.days[dayKey(t)]?.chars ?? 0) >= 10_000
    },
    Achievement(id: "streak_7", title: "Habit Forming", description: "Type 500+ characters 7 days in a row") { g, t in
        streakDays(g.stats, t) >= 7
    },
    Achievement(id: "night_owl", title: "Night Owl", description: "Type 200 characters between 2 and 5 AM") { g, t in
        let h = hour(t)
        return h >= 2 && h < 5 && g.nightChars >= 200
    },
]

public final class Game {
    public var stats: Stats
    public var config: GameConfig
    public private(set) var combo = 0
    public var sessionPeakWpm = 0
    var nightChars = 0
    private var charTimes: [Double] = []
    private var accuracyWindow: [Bool] = []
    private var lastKeyAt: Double = 0
    private var heat: Double = 0
    private var heatAt: Double = 0
    private var xpFraction: Double = 0

    public init(stats: Stats = Stats(), config: GameConfig = GameConfig()) {
        self.stats = stats
        self.config = config
    }

    public func key(_ cls: KeyClass, at t: Double) -> [GameEvent] {
        var events = tick(t)
        let today = dayKey(t)
        stats.days[today, default: DayStats()].keys += 1
        stats.totalKeys += 1
        lastKeyAt = t

        switch cls {
        case .other:
            return events
        case .backspace:
            pushAccuracy(false)
            return events
        case .char, .enter:
            break
        }

        // A productive keystroke.
        pushAccuracy(true)
        combo += 1
        charTimes.append(t)
        stats.totalChars += 1
        stats.days[today]!.chars += 1
        let h = hour(t)
        if h >= 2 && h < 5 { nightChars += 1 }

        decayHeat(t)
        heat = min(1, heat + heatPerChar)

        let levelBefore = levelForXp(stats.totalXp)
        xpFraction += multiplierFor(combo, step: config.comboStep, max: config.maxMultiplier) * accuracy()
        let gained = Int(xpFraction)
        xpFraction -= Double(gained)
        stats.totalXp += gained
        stats.days[today]!.xp += gained
        let levelAfter = levelForXp(stats.totalXp)
        if levelAfter > levelBefore { events.append(.milestone(.level, value: levelAfter)) }

        if combo % max(1, config.comboMilestone) == 0 { events.append(.milestone(.combo, value: combo)) }
        stats.days[today]!.bestCombo = max(stats.days[today]!.bestCombo, combo)
        stats.bestCombo = max(stats.bestCombo, combo)

        let current = wpm(t)
        if charTimes.count >= wpmQualifyChars {
            sessionPeakWpm = max(sessionPeakWpm, current)
            stats.days[today]!.bestWpm = max(stats.days[today]!.bestWpm, current)
            if current > stats.bestWpm {
                // Only celebrate records that move by at least 5 WPM to avoid spam.
                if current / 5 > stats.bestWpm / 5 && stats.bestWpm > 0 {
                    events.append(.milestone(.record, value: current))
                }
                stats.bestWpm = current
            }
        }

        events.append(contentsOf: checkAchievements(t))
        return events
    }

    /// Advance time without a key: breaks stale combos.
    public func tick(_ t: Double) -> [GameEvent] {
        if combo > 0 && t - lastKeyAt > config.comboGapMs {
            let broken = combo
            combo = 0
            return [.comboBreak(combo: broken)]
        }
        return []
    }

    public func wpm(_ t: Double) -> Int {
        while let first = charTimes.first, t - first > wpmWindowMs { charTimes.removeFirst() }
        guard let first = charTimes.first else { return 0 }
        let span = min(wpmWindowMs, max(wpmMinSpanMs, t - first))
        return Int((Double(charTimes.count) / 5 * (60_000 / span)).rounded())
    }

    public func accuracy() -> Double {
        accuracyWindow.isEmpty ? 1 : Double(accuracyWindow.filter { $0 }.count) / Double(accuracyWindow.count)
    }

    public func live(_ t: Double) -> Live {
        decayHeat(t)
        let level = levelForXp(stats.totalXp)
        let base = xpForLevel(level)
        return Live(
            wpm: wpm(t),
            sessionPeakWpm: sessionPeakWpm,
            combo: combo,
            multiplier: multiplierFor(combo, step: config.comboStep, max: config.maxMultiplier),
            accuracy: accuracy(),
            level: level,
            rank: rankFor(level),
            levelXp: stats.totalXp - base,
            levelSpan: xpForLevel(level + 1) - base,
            heat: heat,
            today: stats.days[dayKey(t)] ?? DayStats(),
            idleMs: lastKeyAt > 0 ? t - lastKeyAt : .infinity
        )
    }

    private func pushAccuracy(_ ok: Bool) {
        accuracyWindow.append(ok)
        if accuracyWindow.count > accuracyWindowSize { accuracyWindow.removeFirst() }
    }

    private func decayHeat(_ t: Double) {
        if heatAt > 0 { heat *= exp(-(t - heatAt) / heatTauMs) }
        heatAt = t
    }

    private func checkAchievements(_ t: Double) -> [GameEvent] {
        var out: [GameEvent] = []
        for a in achievements where stats.achievements[a.id] == nil && a.check(self, t) {
            stats.achievements[a.id] = t
            out.append(.achievement(id: a.id, title: a.title, description: a.description))
        }
        return out
    }
}
