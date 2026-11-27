// Checks for MadnessCore: `swift run selftest`. Exits non-zero on failure.

import Foundation
import MadnessCore

var failures = 0
var passed = 0

func check(_ ok: @autoclosure () -> Bool, _ what: String, line: Int = #line) {
    if ok() {
        passed += 1
    } else {
        failures += 1
        print("✗ line \(line): \(what)")
    }
}

func test(_ name: String, _ body: () throws -> Void) {
    let before = failures
    do { try body() } catch {
        failures += 1
        print("✗ \(name) threw \(error)")
    }
    print(failures == before ? "✓ \(name)" : "✗ \(name)")
}

// MARK: - Game

test("typing builds combo, XP and WPM") {
    let game = Game()
    var t = 1_000_000.0
    for _ in 0..<100 { _ = game.key(.char, at: t); t += 100 } // 10 chars/s = 120 WPM
    let live = game.live(t)
    check(live.combo == 100, "combo \(live.combo)")
    check(game.stats.totalXp > 100, "xp \(game.stats.totalXp)")
    check((110...130).contains(live.wpm), "wpm \(live.wpm)")
}

test("combo milestone every 25 keys") {
    let game = Game()
    var t = 1_000_000.0
    var milestones: [Int] = []
    for _ in 0..<50 {
        for case let .milestone(.combo, value) in game.key(.char, at: t) { milestones.append(value) }
        t += 100
    }
    check(milestones == [25, 50], "milestones \(milestones)")
}

test("a pause breaks the combo") {
    let game = Game()
    var t = 1_000_000.0
    for _ in 0..<40 { _ = game.key(.char, at: t); t += 100 }
    check(game.tick(t + 2000) == [.comboBreak(combo: 40)], "combo break event")
    check(game.combo == 0, "combo reset")
}

test("backspace lowers accuracy but keeps the combo") {
    let game = Game()
    _ = game.key(.char, at: 1000)
    _ = game.key(.backspace, at: 1100)
    check(game.accuracy() == 0.5, "accuracy \(game.accuracy())")
    check(game.combo == 1, "combo \(game.combo)")
}

test("other keys don't count as characters") {
    let game = Game()
    _ = game.key(.other, at: 1000)
    check(game.stats.totalChars == 0, "chars")
    check(game.stats.totalKeys == 1, "keys")
}

test("levels, ranks and multipliers") {
    check(levelForXp(0) == 0, "level 0")
    check(levelForXp(xpForLevel(10)) == 10, "level 10")
    check(levelForXp(xpForLevel(10) - 1) == 9, "just under 10")
    check(rankFor(0) == "Hunt & Peck", "rank 0")
    check(rankFor(11) == "Combo Crusher", "rank 11")
    check(multiplierFor(0) == 1, "×1")
    check(multiplierFor(50) == 2, "×2")
    check(multiplierFor(10_000) == 5, "capped ×5")
}

test("stats round-trip through JSON") {
    let game = Game()
    for i in 0..<30 { _ = game.key(.char, at: 1_000_000 + Double(i) * 100) }
    let data = try JSONEncoder().encode(game.stats)
    let decoded = try JSONDecoder().decode(Stats.self, from: data)
    check(decoded == game.stats, "decoded stats equal")
}

// MARK: - Speed colors

test("tiers with hysteresis") {
    check(Speed.tierIndex(10) == 0, "slow")
    check(Speed.tierIndex(25) == 1, "green")
    check(Speed.tierIndex(90) == 4, "red")
    check(Speed.tierFor(83, current: 4) == 4, "holds red just under 85")
    check(Speed.tierFor(70, current: 4) == 3, "drops to orange")
}

test("insane tier above red") {
    check(Speed.tierIndex(109) == 4, "still red at 109")
    check(Speed.tierIndex(110) == Speed.insaneTier, "insane from 110")
    check(Speed.tierFor(107, current: 5) == 5, "holds insane just under 110")
    check(Speed.tierFor(100, current: 5) == 4, "drops back to red")
    check(Speed.color(5) == RGB(hex: "#ff2bd6"), "insane color")
    check(Speed.intensity(wpm: 85, heat: 0) == 1, "full effect strength from red")
}

test("colors switch off once idle") {
    check(Speed.speedTier(wpm: 90, idleMs: 0, current: 0) == 4, "typing")
    check(Speed.speedTier(wpm: 90, idleMs: Speed.colorIdleMs, current: 4) == 4, "still on at the limit")
    check(Speed.speedTier(wpm: 90, idleMs: Speed.colorIdleMs + 1, current: 4) == 0, "off after")
    check(Speed.color(0) == nil, "tier 0 has no color")
    check(Speed.color(4) == RGB(hex: "#ff3030"), "red")
}

test("fade holds, then eases out smoothly") {
    check(Speed.idleFade(0) == 1, "full while typing")
    check(Speed.idleFade(Speed.tintFadeDelayMs) == 1, "full until the fade starts")
    check(Speed.idleFade(Speed.colorIdleMs) == 0, "gone when colors switch off")
    var previous = 1.0
    for ms in stride(from: 0.0, through: Speed.colorIdleMs, by: 100) {
        let f = Speed.idleFade(ms)
        check(f <= previous && previous - f < 0.15, "smooth at \(ms)ms: \(previous) -> \(f)")
        previous = f
    }
}

test("hex colors") {
    check(RGB(hex: "#5fd787") == RGB(95, 215, 135), "parses")
    check(RGB(hex: "red") == nil, "rejects names")
}

print("\n\(passed) checks passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
