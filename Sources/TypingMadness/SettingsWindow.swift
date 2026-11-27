// The Settings window: every on/off switch and every tunable number, grouped
// into tabs. Changes save to UserDefaults and apply right away.

import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?
    private let loginItem: LoginItem
    private let preview: () -> Void
    private let previewInsane: () -> Void

    init(loginItem: LoginItem, preview: @escaping () -> Void, previewInsane: @escaping () -> Void) {
        self.loginItem = loginItem
        self.preview = preview
        self.previewInsane = previewInsane
    }

    func show() {
        loginItem.refresh()
        if window == nil {
            let view = SettingsView(loginItem: loginItem, preview: preview, previewInsane: previewInsane)
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "Typing Madness Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private typealias K = Tuning.Key
private let D = Tuning.defaults

/// Speed tiers as picker choices; 9 means "never".
private let tierChoices: [(Int, String)] = [
    (1, "Green"), (2, "Yellow"), (3, "Orange"), (4, "Red"), (5, "Insane"), (9, "Never"),
]

private struct SettingsView: View {
    let loginItem: LoginItem
    let preview: () -> Void
    let previewInsane: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                EffectsTab(loginItem: loginItem).tabItem { Text("Effects") }
                MeterTab().tabItem { Text("Meter") }
                SpeedTab().tabItem { Text("Speed & Colors") }
                FireworksTab().tabItem { Text("Fireworks & Stars") }
                InsaneTab(preview: previewInsane).tabItem { Text("Insane") }
                ShakeTab().tabItem { Text("Shake") }
                GameTab().tabItem { Text("Game") }
            }
            .padding([.horizontal, .top])
            HStack {
                Button("Restore Defaults") { Tuning.reset() }
                    .help("Puts every number and color back. On/off switches stay as they are.")
                Spacer()
                Text("Preview:").foregroundStyle(.secondary)
                Button("Celebration", action: preview)
                    .help("Plays a big milestone (flash, badge, fireworks, shake) and a few seconds of fast-typing stars over the window behind this one.")
                Button("Insane", action: previewInsane)
                    .help("Shows 4 seconds of Insane: the screen fire, flamethrowers and laser beams, with your current settings.")
            }
            .padding()
        }
        .frame(width: 640, height: 560)
    }
}

// MARK: - Tabs

private struct EffectsTab: View {
    @ObservedObject var loginItem: LoginItem
    @AppStorage("tint") private var tint = true
    @AppStorage("border") private var border = true
    @AppStorage("flash") private var flash = true
    @AppStorage("badges") private var badges = true
    @AppStorage("fireworks") private var fireworks = true
    @AppStorage("shake") private var shake = true
    @AppStorage(K.comboMilestone) private var comboMilestone = D.comboMilestone
    @AppStorage(K.flashStrength) private var flashStrength = D.flashStrength
    @AppStorage(K.badgeSeconds) private var badgeSeconds = D.badgeSeconds

    var body: some View {
        Form {
            Section {
                ToggleRow("Start at login", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.set($0) }),
                          help: Help.startAtLogin)
                if let note = loginItem.note {
                    Text(note).font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("App")
            }
            Section("Turn on") {
                ToggleRow("Tint the active window", isOn: $tint, help: Help.tint)
                ToggleRow("Glowing border", isOn: $border, help: Help.border)
                ToggleRow("Flash on milestones", isOn: $flash, help: Help.flash)
                ToggleRow("Milestone badges", isOn: $badges, help: Help.badges)
                ToggleRow("Fireworks and stars", isOn: $fireworks, help: Help.fireworks)
                ToggleRow("Shake window when typing fast", isOn: $shake, help: Help.shake)
            }
            Section("Milestones") {
                IntStepper("Combo milestone every", value: $comboMilestone, range: 5...500, step: 5, unit: "keys",
                           help: Help.comboMilestone)
                SliderRow("Flash brightness", value: $flashStrength, range: 0...1, format: .percent,
                          help: Help.flashStrength)
                SliderRow("Badge stays for", value: $badgeSeconds, range: 0.5...6, format: .seconds,
                          help: Help.badgeSeconds)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SpeedTab: View {
    @AppStorage(K.tierWpm[0]) private var wpm1 = D.tierWpm[0]
    @AppStorage(K.tierWpm[1]) private var wpm2 = D.tierWpm[1]
    @AppStorage(K.tierWpm[2]) private var wpm3 = D.tierWpm[2]
    @AppStorage(K.tierWpm[3]) private var wpm4 = D.tierWpm[3]
    @AppStorage(K.tierWpm[4]) private var wpm5 = D.tierWpm[4]
    @AppStorage(K.tierColor[0]) private var color1 = D.tierColors[0]
    @AppStorage(K.tierColor[1]) private var color2 = D.tierColors[1]
    @AppStorage(K.tierColor[2]) private var color3 = D.tierColors[2]
    @AppStorage(K.tierColor[3]) private var color4 = D.tierColors[3]
    @AppStorage(K.tierColor[4]) private var color5 = D.tierColors[4]
    @AppStorage(K.tintStrength) private var tintStrength = D.tintStrength
    @AppStorage(K.glowWidth) private var glowWidth = D.glowWidth
    @AppStorage(K.holdSeconds) private var holdSeconds = D.holdSeconds
    @AppStorage(K.fadeSeconds) private var fadeSeconds = D.fadeSeconds

    var body: some View {
        Form {
            Section {
                TierRow(name: "Green", wpm: $wpm1, hex: $color1, help: Help.tier("Green", first: true))
                TierRow(name: "Yellow", wpm: $wpm2, hex: $color2, help: Help.tier("Yellow"))
                TierRow(name: "Orange", wpm: $wpm3, hex: $color3, help: Help.tier("Orange"))
                TierRow(name: "Red", wpm: $wpm4, hex: $color4, help: Help.tier("Red"))
                TierRow(name: "Insane", wpm: $wpm5, hex: $color5, help: Help.insaneTier)
            } header: {
                Text("Speed tiers")
            } footer: {
                Text("Each color starts at its WPM. Keep them in rising order.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Window") {
                SliderRow("Tint strength", value: $tintStrength, range: 0...0.6, format: .percent,
                          help: Help.tintStrength)
                SliderRow("Glow border width", value: $glowWidth, range: 1...14, format: .points,
                          help: Help.glowWidth)
                SliderRow("Colors hold after you stop", value: $holdSeconds, range: 0...15, format: .seconds,
                          help: Help.holdSeconds)
                SliderRow("Then fade out over", value: $fadeSeconds, range: 0.5...10, format: .seconds,
                          help: Help.fadeSeconds)
            }
        }
        .formStyle(.grouped)
    }
}

private struct FireworksTab: View {
    @AppStorage(K.fireworksAchievement) private var achievement = D.fireworksAchievement
    @AppStorage(K.fireworksLevel) private var level = D.fireworksLevel
    @AppStorage(K.fireworksRecord) private var record = D.fireworksRecord
    @AppStorage(K.fireworksCombo) private var combo = D.fireworksCombo
    @AppStorage(K.fireworksComboEvery) private var comboEvery = D.fireworksComboEvery
    @AppStorage(K.fireworkSize) private var size = D.fireworkSize
    @AppStorage(K.fastEffectsFrom) private var from = D.fastEffectsFrom
    @AppStorage(K.fastEffectsAmount) private var amount = D.fastEffectsAmount
    @AppStorage(K.starsPerJump) private var starsPerJump = D.starsPerJump
    @AppStorage(K.starHeight) private var starHeight = D.starHeight
    @AppStorage(K.starSize) private var starSize = D.starSize

    var body: some View {
        Form {
            Section("Fireworks on milestones") {
                IntStepper("Achievement", value: $achievement, range: 0...60, unit: "bursts",
                           help: Help.fireworksAchievement)
                IntStepper("Level up", value: $level, range: 0...60, unit: "bursts", help: Help.fireworksLevel)
                IntStepper("New WPM record", value: $record, range: 0...60, unit: "bursts", help: Help.fireworksRecord)
                IntStepper("Big combo", value: $combo, range: 0...60, unit: "bursts", help: Help.fireworksCombo)
                IntStepper("Big combo every", value: $comboEvery, range: 25...1000, step: 25, unit: "keys",
                           help: Help.fireworksComboEvery)
                SliderRow("Burst size", value: $size, range: 0.3...2.5, format: .times, help: Help.fireworkSize)
            }
            Section("While typing fast") {
                TierPicker("Start at", selection: $from, help: Help.fastEffectsFrom)
                SliderRow("Amount", value: $amount, range: 0.2...4, format: .times, help: Help.fastEffectsAmount)
                IntStepper("Stars per jump", value: $starsPerJump, range: 1...15, unit: "stars", help: Help.starsPerJump)
                SliderRow("Jump height", value: $starHeight, range: 0.1...1, format: .percentOfWindow,
                          help: Help.starHeight)
                SliderRow("Star size", value: $starSize, range: 0.4...2.5, format: .times, help: Help.starSize)
            }
        }
        .formStyle(.grouped)
    }
}

private struct InsaneTab: View {
    let preview: () -> Void
    @AppStorage(K.tierWpm[4]) private var wpm = D.tierWpm[4]
    @AppStorage(K.insaneFire) private var fire = D.insaneFire
    @AppStorage(K.insaneFireAmount) private var fireAmount = D.insaneFireAmount
    @AppStorage(K.insaneFireHeight) private var fireHeight = D.insaneFireHeight
    @AppStorage(K.insaneGunsPerSecond) private var guns = D.insaneGunsPerSecond
    @AppStorage(K.insaneGunPower) private var gunPower = D.insaneGunPower
    @AppStorage(K.insaneLasers) private var lasers = D.insaneLasers
    @AppStorage(K.insaneLasersPerSecond) private var lasersPerSecond = D.insaneLasersPerSecond
    @AppStorage(K.insaneLaserWidth) private var laserWidth = D.insaneLaserWidth

    var body: some View {
        Form {
            Section {
                IntStepper("Insane from", value: $wpm, range: 30...300, step: 5, unit: "WPM", help: Help.insaneFrom)
                LabeledContent {
                    Button("Preview Insane", action: preview)
                } label: {
                    HelpLabel(title: "See it now", help: Help.insanePreview)
                }
            } footer: {
                Text("Type this fast and the whole screen catches fire while laser beams shoot across it. Its color is set in Speed & Colors.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Screen on fire") {
                ToggleRow("Fire", isOn: $fire, help: Help.insaneFire)
                SliderRow("Amount", value: $fireAmount, range: 0.2...3, format: .times, help: Help.insaneFireAmount)
                    .disabled(!fire)
                SliderRow("Height", value: $fireHeight, range: 0.1...0.8, format: .percentOfScreen,
                          help: Help.insaneFireHeight)
                    .disabled(!fire)
                SliderRow("Flamethrowers", value: $guns, range: 0...6, format: .perSecond, help: Help.insaneGuns)
                    .disabled(!fire)
                SliderRow("Flamethrower power", value: $gunPower, range: 0.4...2.5, format: .times,
                          help: Help.insaneGunPower)
                    .disabled(!fire || guns == 0)
            }
            Section("Lasers") {
                ToggleRow("Laser beams", isOn: $lasers, help: Help.insaneLasers)
                SliderRow("Beams per second", value: $lasersPerSecond, range: 0.5...20, format: .perSecond,
                          help: Help.insaneLasersPerSecond)
                    .disabled(!lasers)
                SliderRow("Thickness", value: $laserWidth, range: 1...12, format: .points, help: Help.insaneLaserWidth)
                    .disabled(!lasers)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShakeTab: View {
    @AppStorage("shake") private var shake = true
    @AppStorage(K.shakeFrom) private var from = D.shakeFrom
    @AppStorage(K.shakeStrength) private var strength = D.shakeStrength
    @AppStorage(K.milestoneShake) private var milestone = D.milestoneShake
    @AppStorage(K.maxShake) private var maxShake = D.maxShake
    @AppStorage(K.badgeShake) private var badgeShake = D.badgeShake

    var body: some View {
        Form {
            Section {
                ToggleRow("Shake window when typing fast", isOn: $shake, help: Help.shake)
                TierPicker("Start at", selection: $from, help: Help.shakeFrom)
                SliderRow("Strength at top speed", value: $strength, range: 0...15, format: .points,
                          help: Help.shakeStrength)
                SliderRow("Milestone jolt", value: $milestone, range: 0...3, format: .times, help: Help.milestoneShake)
                SliderRow("Never more than", value: $maxShake, range: 1...25, format: .points, help: Help.maxShake)
            } header: {
                Text("Window")
            } footer: {
                Text("Moving the window needs Accessibility permission. Without it, and in full-screen windows, only the glow and effects shake.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                SliderRow("Badge shake", value: $badgeShake, range: 0...3, format: .times, help: Help.badgeShake)
            } header: {
                Text("Badges")
            } footer: {
                Text("Meter shake is in the Meter tab.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct MeterTab: View {
    @AppStorage("meter") private var meter = true
    @AppStorage(K.meterOnWindow) private var onWindow = D.meterOnWindow
    @AppStorage(K.meterPosition) private var position = D.meterPosition.rawValue
    @AppStorage(K.meterOpacity) private var opacity = D.meterOpacity
    @AppStorage(K.meterBackground) private var background = D.meterBackground
    @AppStorage(K.meterShake) private var meterShake = D.meterShake
    @AppStorage(K.meterLocked) private var locked = D.meterLocked
    @AppStorage(K.meterLayout) private var layout = D.meterLayout.rawValue

    var body: some View {
        Form {
            Section {
                ToggleRow("Show the meter", isOn: $meter, help: Help.meter)
            } footer: {
                Text("Turn it off to keep only the effects on your window. The WPM in the menu bar stays.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent {
                    Picker("Dock to", selection: $onWindow) {
                        Text("Screen").tag(false)
                        Text("Window you're typing in").tag(true)
                    }
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    HelpLabel(title: "Dock to", help: Help.meterDock)
                }
                LabeledContent {
                    Picker("Position", selection: $position) {
                        ForEach(MeterPosition.allCases, id: \.rawValue) { p in
                            Text(p.title).tag(p.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    // Choosing a position (even the same one) snaps a dragged meter back.
                    .onChange(of: position) { _ in Tuning.resetMeterSpot() }
                } label: {
                    HelpLabel(title: "Position", help: Help.meterPosition)
                }
                ToggleRow("Lock in place", isOn: $locked, help: Help.meterLocked)
                LabeledContent {
                    Button("Reset Position") { Tuning.resetMeterSpot() }
                } label: {
                    HelpLabel(title: "Dragged somewhere else?", help: Help.meterReset)
                }
            } header: {
                Text("Placement")
            } footer: {
                Text("Drag the middle of the meter to move it anywhere. Picking a Position puts it back at that spot.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent {
                    Picker("Layout", selection: $layout) {
                        ForEach(MeterLayout.allCases, id: \.rawValue) { l in
                            Text(l.title).tag(l.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    // A new layout starts at its own natural size.
                    .onChange(of: layout) { _ in Tuning.resetMeterSize() }
                } label: {
                    HelpLabel(title: "Layout", help: Help.meterLayout)
                }
                LabeledContent {
                    Button("Reset Size") { Tuning.resetMeterSize() }
                } label: {
                    HelpLabel(title: "Resized it?", help: Help.meterResetSize)
                }
            } header: {
                Text("Size and layout")
            } footer: {
                Text("Drag any edge of the meter to resize it. With Fit to shape, a long thin meter shows one line, a wide one two lines, and a squarish one a stacked view.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Look") {
                SliderRow("Opacity", value: $opacity, range: 0.15...1, format: .percent, help: Help.meterOpacity)
                SliderRow("Background", value: $background, range: 0...1, format: .percent, help: Help.meterBackground)
                SliderRow("Shake", value: $meterShake, range: 0...3, format: .times, help: Help.meterShake)
            }
        }
        .formStyle(.grouped)
    }
}

private struct GameTab: View {
    @AppStorage(K.comboGapSeconds) private var gap = D.comboGapSeconds
    @AppStorage(K.comboStep) private var step = D.comboStep
    @AppStorage(K.maxMultiplier) private var maxMultiplier = D.maxMultiplier

    var body: some View {
        Form {
            Section("Combo and XP") {
                SliderRow("Combo breaks after a pause of", value: $gap, range: 0.3...5, format: .seconds,
                          help: Help.comboGap)
                IntStepper("XP multiplier +×0.5 every", value: $step, range: 5...200, step: 5, unit: "combo keys",
                           help: Help.comboStep)
                SliderRow("Max XP multiplier", value: $maxMultiplier, range: 1...20, format: .times,
                          help: Help.maxMultiplier)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Rows

private enum ValueFormat {
    case percent, percentOfWindow, percentOfScreen, seconds, points, times, perSecond

    func text(_ v: Double) -> String {
        switch self {
        case .percent: return "\(Int((v * 100).rounded()))%"
        case .percentOfWindow: return "\(Int((v * 100).rounded()))% of window"
        case .percentOfScreen: return "\(Int((v * 100).rounded()))% of screen"
        case .perSecond: return String(format: "%.1f / s", v)
        case .seconds: return String(format: "%.1f s", v)
        case .points: return String(format: "%.0f pt", v)
        case .times: return String(format: "×%.1f", v)
        }
    }
}

/// A row label with a ? button that explains the setting.
private struct HelpLabel: View {
    let title: String
    let help: String
    // Not @State: that's a macro, and its plugin only ships with full Xcode.
    @StateObject private var popover = PopoverState()

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            Button {
                popover.showing.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(help)
            .accessibilityLabel("About \(title)")
            .popover(isPresented: $popover.showing, arrowEdge: .trailing) {
                Text(help)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 300, alignment: .leading)
                    .padding(14)
            }
        }
    }
}

private final class PopoverState: ObservableObject {
    @Published var showing = false
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let help: String

    init(_ title: String, isOn: Binding<Bool>, help: String) {
        self.title = title
        _isOn = isOn
        self.help = help
    }

    var body: some View {
        LabeledContent {
            Toggle(title, isOn: $isOn).labelsHidden()
        } label: {
            HelpLabel(title: title, help: help)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: ValueFormat
    let help: String

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: ValueFormat, help: String) {
        self.title = title
        _value = value
        self.range = range
        self.format = format
        self.help = help
    }

    var body: some View {
        LabeledContent {
            HStack {
                Slider(value: $value, in: range)
                Text(format.text(value))
                    .monospacedDigit()
                    .frame(width: 110, alignment: .trailing)
            }
        } label: {
            HelpLabel(title: title, help: help)
        }
    }
}

private struct IntStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let help: String

    init(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: String, help: String) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.help = help
    }

    var body: some View {
        LabeledContent {
            Stepper(value: $value, in: range, step: step) {
                Text("\(value) \(unit)").monospacedDigit()
            }
        } label: {
            HelpLabel(title: title, help: help)
        }
    }
}

private struct TierPicker: View {
    let title: String
    @Binding var selection: Int
    let help: String

    init(_ title: String, selection: Binding<Int>, help: String) {
        self.title = title
        _selection = selection
        self.help = help
    }

    var body: some View {
        LabeledContent {
            Picker(title, selection: $selection) {
                ForEach(tierChoices, id: \.0) { tier, name in
                    Text(tier == 9 ? name : "\(name) tier").tag(tier)
                }
            }
            .labelsHidden()
            .fixedSize()
        } label: {
            HelpLabel(title: title, help: help)
        }
    }
}

private struct TierRow: View {
    let name: String
    @Binding var wpm: Int
    @Binding var hex: String
    let help: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 16) {
                Stepper(value: $wpm, in: 5...250, step: 5) {
                    Text("from \(wpm) WPM").monospacedDigit()
                }
                ColorPicker("", selection: color, supportsOpacity: false)
                    .labelsHidden()
            }
        } label: {
            HelpLabel(title: name, help: help)
        }
    }

    /// The stored "#rrggbb" as a SwiftUI color.
    private var color: Binding<Color> {
        Binding(
            get: {
                let c = RGBHex(hex)
                return Color(.sRGB, red: c.r, green: c.g, blue: c.b)
            },
            set: { newValue in
                guard let c = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                hex = String(format: "#%02x%02x%02x",
                             Int((c.redComponent * 255).rounded()),
                             Int((c.greenComponent * 255).rounded()),
                             Int((c.blueComponent * 255).rounded()))
            }
        )
    }
}

private struct RGBHex {
    var r = 1.0, g = 1.0, b = 1.0

    init(_ hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let n = Int(s, radix: 16) else { return }
        r = Double((n >> 16) & 255) / 255
        g = Double((n >> 8) & 255) / 255
        b = Double(n & 255) / 255
    }
}

// MARK: - Help text

/// What each setting does and what it affects, shown by its ? button.
private enum Help {
    // Effects
    static let tint = "Colors the window you're typing in with your speed color (green, yellow, orange, red). The faster you type, the stronger it gets. Set how strong in Speed & Colors › Tint strength, and when each color starts in Speed & Colors › Speed tiers."
    static let border = "Draws a glowing outline in your speed color around the window you're typing in. Set its thickness in Speed & Colors › Glow border width."
    static let flash = "On milestones, flashes the whole window and pulses a thick, bright border. Combos flash twice; level-ups, new records and achievements flash three times. Set the brightness with Flash brightness below."
    static let badges = "On milestones, shows big text that pops in and shakes in the middle of the window, such as COMBO 50!, LEVEL 3 or ★ an achievement's name. Set how long it stays with Badge stays for below."
    static let fireworks = "Fireworks on milestones, plus jumping stars and small fireworks while you type fast. Set how many, how big and from which speed in the Fireworks & Stars tab."
    static let shake = "Shakes the window you're typing in when you type fast, and jolts it on milestones. It always goes back to its exact spot. Needs Accessibility permission. Full-screen windows can't be moved, so there only the glow shakes. Set strength and when it starts in the Shake tab."
    static let meter = "The floating bar with live WPM, combo, XP multiplier, accuracy, level and XP. It also shows notices and warnings, such as a missing permission. Turn it off to keep only the effects; the menu-bar WPM stays. Set where it sits and how see-through it is below."
    static let startAtLogin = "Opens Typing Madness automatically when you log in to your Mac. macOS lists it in System Settings › General › Login Items, where you can also turn it off. Works for the installed app, not for `swift run`."
    static let meterDock = "Screen keeps the meter at an edge or corner of the screen you're typing on. Window you're typing in docks it inside that window's edge, so it follows the window as you switch and move windows. Choose which edge or corner with Position."
    static let meterPosition = "Which corner or edge the meter sits in, on the screen or on the window it's docked to (see Dock to). At the top, it grows downward when a notice line appears. If you've dragged the meter, picking a position snaps it back."
    static let meterLocked = "Locks the meter where it is. Locked, it can't be moved or resized and clicks go straight through it to the window below. Unlocked, you can drag it anywhere and resize it by its edges, but clicks on the meter itself don't reach the window under it."
    static let meterLayout = "How the stats are arranged. Fit to shape picks, as you resize the meter, the layout that fits it with the biggest text: Single line for a long thin strip, Two lines for a wide bar, Compact for a short box (big WPM number on the left, the other stats beside it), Square for a stacked view with a big WPM number on top. Or choose one to always use it. The text always scales to fill the meter."
    static let meterResetSize = "If you've resized the meter by dragging its edges, this puts it back to its layout's natural size. Choosing a Layout does the same."
    static let meterReset = "If you've dragged the meter, this puts it back at the spot chosen in Position. Dragged spots are kept separately for Screen and for Window you're typing in."
    static let meterOpacity = "How see-through the whole meter is, text included. Lower it to make the meter less distracting."
    static let meterBackground = "How dark the background behind the meter's text is. 0% shows only the text, floating over whatever is behind it. The text itself stays fully visible (use Opacity for that)."
    static let comboMilestone = "A combo counts the keys you type without pausing. Each time it reaches a multiple of this number, you get a combo milestone: a flash and a COMBO badge. Lower means more often. Set how long a pause breaks a combo in Game."
    static let flashStrength = "How bright milestone flashes are. 0% turns off the window flash but keeps the border pulse. Big milestones (level-ups, records, achievements) are 10% brighter."
    static let badgeSeconds = "How long a combo badge stays on screen before fading. Level-up, record and achievement badges stay 1 second longer."

    // Speed and colors
    static func tier(_ name: String, first: Bool = false) -> String {
        let below = first ? " Below it there's no color." : ""
        return "From this many words per minute, your speed color is \(name).\(below) The speed color is used by the window tint, the glow border, the meter and the menu-bar WPM. Speed colors also decide when stars, fireworks and the window shake start (see those tabs). Click the swatch to pick a different color. Keep the WPMs in rising order."
    }
    static let insaneTier = "From this many words per minute you're Insane: the top speed color. The whole screen you're typing on catches fire and laser beams shoot across it (set those in the Insane tab). The window shakes 1.5× harder than at Red. Click the swatch to pick its color. Keep the WPMs in rising order."
    static let tintStrength = "How strongly the window is colored at full speed. The tint grows with your speed up to this amount. 0% turns the tint off."
    static let glowWidth = "Thickness of the glowing outline around the window you're typing in."
    static let holdSeconds = "After your last key, colors stay at full strength for this long, then fade."
    static let fadeSeconds = "How long the tint and glow take to fade out after the hold. When the fade ends, your speed color resets until you type again."

    // Fireworks and stars
    static let fireworksAchievement = "How many firework bursts go off when you unlock an achievement. 0 means none."
    static let fireworksLevel = "How many firework bursts go off when you reach a new level. 0 means none."
    static let fireworksRecord = "How many firework bursts go off when you beat your best WPM. 0 means none."
    static let fireworksCombo = "How many firework bursts go off on a big combo. Set which combos count as big with Big combo every. 0 means none."
    static let fireworksComboEvery = "Which combos count as big: every this many keys typed without pausing. Big combos get the fireworks set in Big combo."
    static let fireworkSize = "How big each firework is and how far its sparks fly. Applies to milestone fireworks and the small ones while typing fast."
    static let fastEffectsFrom = "The speed color where stars and small fireworks start appearing while you type. Never turns them off; milestone fireworks still play. Set where each color starts in Speed & Colors."
    static let fastEffectsAmount = "How often stars and small fireworks appear while you type fast. At ×1 that's about 1 a second at yellow and 4 a second at red. They take turns: a jump of stars, then a firework."
    static let starsPerJump = "How many stars fly up together each time stars jump."
    static let starHeight = "How high stars jump on average, as a share of the window's height. They launch from anywhere in the lower half of the window."
    static let starSize = "How big the jumping stars are."

    // Shake
    static let shakeFrom = "The speed color where the window starts shaking while you type. Never stops speed shaking; milestone jolts still happen. Set where each color starts in Speed & Colors."
    static let shakeStrength = "How far the window moves at red speed, in points. Each speed color below red shakes half as much, and Insane shakes 1.5× as much. It shakes a little more during bursts."
    static let milestoneShake = "How hard milestones jolt the window. ×0 turns milestone jolts off; ×2 doubles them."
    static let maxShake = "A limit on how far the window can ever move from its spot, whatever the other settings."
    static let badgeShake = "How hard the big milestone text (COMBO 50!, LEVEL 3, ★ achievements) shakes when it pops in. ×0 keeps it still; big milestones shake harder than combos at any setting."
    static let meterShake = "How hard the floating meter at the bottom of the screen shakes. It shakes more the faster you type and on milestones. ×0 keeps it still."

    // Game
    // Insane
    static let insaneFrom = "The WPM where Insane starts. It's the same number as the Insane row in Speed & Colors. Keep it above Red's WPM."
    static let insanePreview = "Shows 4 seconds of Insane: the screen fire and laser beams, with your current settings, on the screen behind this window."
    static let insaneFire = "At Insane speed, flames burn in from all four edges of the screen and blast out of every corner. They flicker and flare up at random, flamethrowers sweep jets of fire across the screen (see Flamethrowers), and a red glow and embers fill the edges. They die down a moment after you drop below Insane. Clicks go straight through."
    static let insaneFireAmount = "How thick the fire is. Higher looks wilder but uses more graphics power."
    static let insaneFireHeight = "How far into the screen the flames reach, as a share of its height. Flames from the bottom reach the full amount; from the top and sides a bit less."
    static let insaneGuns = "How many flamethrowers pop up each second. Each appears at a random spot on an edge of the screen and sweeps a jet of fire into it for about a second. 0 turns them off."
    static let insaneGunPower = "How far and fast the flamethrower jets shoot. ×1 reaches well past the edge fire; ×2.5 can cross most of the screen."
    static let insaneLasers = "At Insane speed, neon laser beams shoot from one edge of the screen to another and spark where they hit."
    static let insaneLasersPerSecond = "How many laser beams fire each second while you stay at Insane speed."
    static let insaneLaserWidth = "How thick each laser beam is. The glow around it grows with it."

    static let comboGap = "If you pause longer than this between keys, your combo resets to 0. Longer means combos are easier to keep."
    static let comboStep = "Your XP multiplier goes up by ×0.5 every this many combo keys, so long combos earn XP faster."
    static let maxMultiplier = "The highest the XP multiplier can go, however long your combo."
}
