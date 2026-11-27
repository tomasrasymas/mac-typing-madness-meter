// Ties it together: keys feed the game, a 30 fps loop drives the overlay, the
// floating meter and the menu-bar item.

import AppKit
import Carbon.HIToolbox
import MadnessCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let game = Game(stats: StatsStore.load())
    private let tap = KeyTap()
    private let settings = Settings()
    private let shaker = WindowShaker()
    private var tuning = Tuning()
    private let loginItem = LoginItem()
    private let insane = InsaneFX()
    private lazy var settingsWindow = SettingsWindow(
        loginItem: loginItem,
        preview: { [weak self] in self?.preview() },
        previewInsane: { [weak self] in self?.previewInsane() }
    )
    private var overlay: Overlay!
    private var meter: MeterPanel!
    private var statusItem: NSStatusItem!

    /// The one speed tier every color shows.
    private var tier = 0
    private var frameCount = 0
    private var front: FrontWindow.Info?
    private var burst = 0.0
    private var notice: (text: String, color: NSColor, until: Double)?
    private var saveWork: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var lastTitle = ""
    /// Fast keys earn effects; each whole point fires one, alternating a
    /// cluster of stars and a small firework so both show equally often.
    private var effectCredit = 0.0
    private var nextIsStars = true
    private var previewUntil = 0.0
    private var previewInsaneUntil = 0.0

    private static let gold = Overlay.palette[0]
    private static let purple = Overlay.palette[2]

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = Overlay()
        meter = MeterPanel()
        reloadTuning()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reloadTuning()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.image(tier: 0)
        statusItem.button?.imagePosition = .imageLeft
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        tap.onKey = { [weak self] cls in self?.onKey(cls) }
        startTap()
        if settings.shake && !WindowShaker.trusted && !settings.askedAccessibility {
            settings.askedAccessibility = true
            WindowShaker.requestPermission()
        }

        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.frame() }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Picks up changes from the Settings window.
    private func reloadTuning() {
        let new = Tuning(.standard)
        tuning = new
        new.apply(to: game)
        overlay.tuning = new
        meter.tuning = new
    }

    func applicationWillTerminate(_ notification: Notification) {
        shaker.stop()
        StatsStore.save(game.stats)
    }

    // MARK: - Keys

    /// Start the key tap, asking for Input Monitoring and retrying until granted.
    private func startTap() {
        if tap.start() {
            NSLog("TypingMadness: key tap running")
            return
        }
        NSLog("TypingMadness: waiting for Input Monitoring permission")
        KeyTap.requestPermission()
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            // Ask again too: if the entry was removed from System Settings while
            // we were running, this puts Typing Madness back in the list.
            KeyTap.requestPermission()
            if self?.tap.start() == true {
                NSLog("TypingMadness: key tap running")
                timer.invalidate()
            }
        }
    }

    private func onKey(_ cls: KeyClass) {
        if settings.paused { return }
        handle(game.key(cls, at: now()))
        // Typing fast (yellow tier and up) sets off stars and fireworks, more
        // the faster you go: at 85+ WPM that's about 4 effects a second.
        if (cls == .char || cls == .enter) && tier >= tuning.fastEffectsFrom {
            effectCredit += [0, 0.15, 0.2, 0.35, 0.55, 0.8][min(tier, 5)] * tuning.fastEffectsAmount
        }
        scheduleSave()
    }

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .milestone(.combo, let value):
                // Every 25 keys: a flash. Every 100: a firework too.
                let every = max(1, tuning.fireworksComboEvery)
                celebrate("COMBO \(value)!", fireworks: value % every == 0 ? tuning.fireworksCombo : 0)
            case .milestone(.level, let value):
                celebrate("LEVEL \(value)", color: AppDelegate.purple, big: true, fireworks: tuning.fireworksLevel)
                show("▲ LEVEL UP → \(value) · \(rankFor(value))", .systemPurple, seconds: 3)
            case .milestone(.record, let value):
                celebrate("\(value) WPM!", color: AppDelegate.gold, big: true, fireworks: tuning.fireworksRecord)
                show("★ NEW RECORD \(value) WPM", .systemYellow, seconds: 3)
            case let .achievement(_, title, description):
                celebrate("★ \(title)", color: AppDelegate.gold, big: true, fireworks: tuning.fireworksAchievement)
                show("★ ACHIEVEMENT \(title): \(description)", .systemYellow, seconds: 4)
            case let .comboBreak(combo):
                if combo >= 30 { show("✗ combo broken at \(combo)", .systemRed, seconds: 1.5) }
            }
        }
    }

    /// `big` is for level-ups, records and achievements: a triple flash, a
    /// bigger badge and a fireworks show.
    private func celebrate(_ badge: String, color: NSColor? = nil, big: Bool = false, fireworks: Int = 0) {
        burst = big ? 5 : 3
        let color = color ?? Speed.color(max(tier, 1)).map(nsColor) ?? .white
        if settings.flash { overlay.flash(color, big: big) }
        if settings.badges { overlay.badge(badge, color: color, big: big) }
        if settings.fireworks && fireworks > 0 {
            // Big shows go off faster and harder: 16 bursts fill about 2.5s.
            overlay.fireworks(count: fireworks, colors: [color] + Overlay.palette.shuffled(),
                              power: CGFloat((big ? 1.15 : 1) * tuning.fireworkSize), gap: big ? 0.16 : 0.25)
        }
    }

    private func show(_ text: String, _ color: NSColor, seconds: Double) {
        notice = (text, color, now() + seconds * 1000)
    }

    private func scheduleSave() {
        guard saveWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.saveWork = nil
            StatsStore.save(self.game.stats)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    // MARK: - Frame loop

    private func frame() {
        let t = now()
        handle(game.tick(t))
        let live = game.live(t)
        tier = Speed.speedTier(wpm: live.wpm, idleMs: live.idleMs, current: tier)
        frameCount += 1

        // Where you're typing: ~5 times a second is plenty to follow window moves.
        // While our own Settings window is in front, keep showing effects on the
        // window behind it, so changes and previews are visible right away.
        if frameCount % 6 == 1 {
            if settings.paused { front = nil } else if !NSApp.isActive { front = FrontWindow.current() }
        }

        let fade = Speed.idleFade(live.idleMs)
        overlay.update(
            frame: shake(live),
            color: Speed.color(tier),
            intensity: Speed.intensity(wpm: live.wpm, heat: live.heat),
            fade: fade,
            tint: settings.tint,
            border: settings.border
        )

        if settings.meter {
            let amp = min(3, live.heat * 1.6 + burst) * 2 * tuning.meterShake
            let shake = CGPoint(x: .random(in: -amp...amp), y: amp > 2.4 && Bool.random() ? amp / 2 : 0)
            meter.update(live: live, tier: tier, message: message(t), shake: shake, near: front?.frame)
        } else {
            meter.hide()
        }
        burst *= 0.88
        if burst < 0.05 { burst = 0 }

        fastEffects(t)
        // Insane: the whole screen you're typing on catches fire.
        let insaneNow = tier >= Speed.insaneTier && !settings.paused && live.idleMs < 1500
        insane.update(active: insaneNow || t < previewInsaneUntil,
                      screen: front.flatMap { FrontWindow.screen(for: $0.frame) } ?? NSScreen.main,
                      now: t, tuning: tuning)

        if frameCount % 6 == 0 { updateTitle(live) }
    }

    /// Shakes the window you're typing in from 65+ WPM (harder at 85+) and on
    /// milestones. Returns where the overlay goes this frame: locked to the
    /// shaking window, or jiggling on its own if the window can't be moved.
    private func shake(_ live: Live) -> NSRect? {
        guard let base = front?.frame else {
            shaker.stop()
            return nil
        }
        var amp = burst * 1.6 * tuning.milestoneShake
        if tier >= tuning.shakeFrom, live.idleMs < 350 {
            // Full strength at red, half one tier lower, and so on; Insane is 1.5×.
            let share: Double = tier >= Speed.insaneTier ? 1.5 : pow(0.5, Double(4 - min(tier, 4)))
            let heat: Double = 0.6 + 0.4 * live.heat
            amp += tuning.shakeStrength * share * heat
        }
        amp = settings.shake ? min(amp, tuning.maxShake) : 0
        if shaker.update(amplitude: amp, pid: front!.pid), let home = shaker.homeFrame {
            return home.offsetBy(dx: shaker.offset.x, dy: shaker.offset.y)
        }
        if shaker.needsPermission {
            show("⚠ Allow Accessibility so the window itself can shake: menu-bar icon › Allow Accessibility…",
                 .systemOrange, seconds: 3)
        }
        guard amp >= 0.5 else { return base }
        return base.offsetBy(dx: .random(in: -amp...amp), dy: .random(in: -amp...amp) * 0.6)
    }

    /// Fast-typing effects: spends the credit fast keys earned, alternating a
    /// cluster of multicolored stars and a small firework.
    private func fastEffects(_ t: Double) {
        if t < previewUntil { effectCredit += 0.15 } // about 4.5 effects a second
        guard settings.fireworks, !settings.paused else {
            effectCredit = 0
            overlay.stars(rate: 0)
            return
        }
        var stars = 0
        while effectCredit >= 1 {
            effectCredit -= 1
            if nextIsStars {
                stars += tuning.starsPerJump
            } else {
                overlay.fireworks(count: 1, colors: [Overlay.palette.randomElement()!],
                                  power: CGFloat(0.65 * tuning.fireworkSize))
            }
            nextIsStars.toggle()
        }
        // Emit this frame's stars over this one frame (30 fps).
        overlay.stars(rate: Float(stars * 30))
    }

    /// Warnings first, then the latest notice.
    private func message(_ t: Double) -> (String, NSColor)? {
        if !tap.running {
            return ("⚠ Allow Input Monitoring: System Settings › Privacy & Security › Input Monitoring", .systemOrange)
        }
        if IsSecureEventInputEnabled() {
            return ("🔒 Secure input is on (a password field?): keys aren't counted right now", .systemOrange)
        }
        if settings.paused { return ("⏸ Paused: resume from the menu-bar icon", .systemGray) }
        if let notice, notice.until > t { return (notice.text, notice.color) }
        return nil
    }

    /// The menu-bar item: the flaming-key icon for the current speed tier and
    /// the live WPM in the same color.
    private func updateTitle(_ live: Live) {
        let shownTier = settings.paused ? 0 : tier
        let title = settings.paused ? "⏸" : (live.wpm > 0 ? "\(live.wpm)" : "")
        let key = "\(shownTier)|\(title)"
        guard key != lastTitle, let button = statusItem.button else { return }
        lastTitle = key
        button.image = MenuBarIcon.image(tier: shownTier)
        let color = Speed.color(shownTier).map(nsColor)
        button.attributedTitle = NSAttributedString(string: title.isEmpty ? "" : " " + title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: color ?? NSColor.labelColor,
        ])
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let live = game.live(now())
        let s = game.stats
        info(menu, "Level \(live.level) · \(live.rank)  (\(live.levelXp)/\(live.levelSpan) XP)")
        info(menu, "Today: \(live.today.chars) chars · best \(live.today.bestWpm) WPM")
        info(menu, "All time: best \(s.bestWpm) WPM · best combo \(s.bestCombo) · \(s.achievements.count)/\(achievements.count) achievements")
        menu.addItem(.separator())

        toggle(menu, "Tint the active window", settings.tint) { self.settings.tint.toggle() }
        toggle(menu, "Glowing border", settings.border) { self.settings.border.toggle() }
        toggle(menu, "Flash on milestones", settings.flash) { self.settings.flash.toggle() }
        toggle(menu, "Milestone badges", settings.badges) { self.settings.badges.toggle() }
        toggle(menu, "Fireworks and stars", settings.fireworks) { self.settings.fireworks.toggle() }
        toggle(menu, "Shake window when typing fast", settings.shake) { self.settings.shake.toggle() }
        toggle(menu, "Floating meter", settings.meter) { self.settings.meter.toggle() }
        if settings.meter && (tuning.meterScreenSpot != nil || tuning.meterWindowSpot != nil) {
            action(menu, "Reset meter position") { Tuning.resetMeterSpot() }
        }
        action(menu, "Settings…", key: ",") { self.settingsWindow.show() }
        menu.addItem(.separator())
        toggle(menu, "Start at login", LoginItem.isEnabled) { self.loginItem.set(!LoginItem.isEnabled) }
        toggle(menu, "Pause", settings.paused) { self.settings.paused.toggle() }
        if !tap.running {
            action(menu, "Allow Input Monitoring…") {
                KeyTap.requestPermission()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
            }
        }
        if settings.shake && !WindowShaker.trusted {
            action(menu, "Allow Accessibility (to shake windows)…") {
                WindowShaker.requestPermission()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        action(menu, "Reset stats…") { self.confirmReset() }
        menu.addItem(.separator())
        action(menu, "Quit Typing Madness", key: "q") { NSApp.terminate(nil) }
    }

    /// Show the big milestone effects and fast-typing stars without having to
    /// earn them, from the Settings window. Plays over the window behind it.
    private func preview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            celebrate("★ PREVIEW", color: AppDelegate.gold, big: true, fireworks: tuning.fireworksAchievement)
            previewUntil = now() + 4000
        }
    }

    /// Four seconds of the Insane screen fire and lasers, without typing 110 WPM,
    /// from the Settings window.
    private func previewInsane() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            previewInsaneUntil = now() + 4000
        }
    }

    private func info(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func toggle(_ menu: NSMenu, _ title: String, _ on: Bool, _ run: @escaping () -> Void) {
        let item = action(menu, title, run)
        item.state = on ? .on : .off
    }

    @discardableResult
    private func action(_ menu: NSMenu, _ title: String, key: String = "", _ run: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key, run: run)
        menu.addItem(item)
        return item
    }

    private func confirmReset() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset all Typing Madness stats?"
        alert.informativeText = "Levels, XP, records and achievements go back to zero. This can't be undone."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            game.stats = Stats()
            game.sessionPeakWpm = 0
            StatsStore.save(game.stats)
        }
    }
}

/// A menu item that runs a closure.
private final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, keyEquivalent: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}

func now() -> Double { Date().timeIntervalSince1970 * 1000 }
