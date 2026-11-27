// The floating meter: a small dark panel showing WPM, combo, accuracy, level
// and XP. It sits in a corner or edge of the screen you're typing on, or docked
// to the window you're typing in. It shakes harder the faster you type.
//
// Drag it to move it; drag an edge to resize it. Its layout follows its shape
// (one line, two lines, compact or square), and the text scales to fill it. Locked,
// it's click-through. It never takes focus from the app you're typing in.

import AppKit
import MadnessCore

final class MeterPanel {
    private let panel: NSPanel
    private let view = MeterView()
    /// Gap from the screen or window edge.
    private static let margin: CGFloat = 16

    /// Opacity, background, layout, size, placement and lock from Settings.
    var tuning = Tuning() {
        didSet {
            panel.alphaValue = CGFloat(tuning.meterOpacity)
            view.backgroundAlpha = CGFloat(tuning.meterBackground)
            view.chosenLayout = tuning.meterLayout
            panel.hasShadow = tuning.meterBackground > 0.5
            panel.ignoresMouseEvents = tuning.meterLocked
            view.needsDisplay = true
        }
    }
    /// The window the meter was last placed against, for saving a dragged spot.
    private var lastAnchor: NSRect?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = view
        view.onMoved = { [weak self] in self?.saveSpot() }
        view.onResized = { [weak self] in self?.saveSize() }
    }

    /// Remember where the user dropped the meter: on the screen, or relative to
    /// the docked window's top-left corner so it follows that window. The spot
    /// is the meter's bottom-left corner, not counting a notice strip under it.
    private func saveSpot() {
        let d = UserDefaults.standard
        let origin = NSPoint(x: panel.frame.minX, y: panel.frame.minY + view.stripHeight)
        if tuning.meterOnWindow, let anchor = lastAnchor {
            d.set([origin.x - anchor.minX, origin.y - anchor.maxY], forKey: Tuning.Key.meterWindowSpot)
        } else {
            d.set([origin.x, origin.y], forKey: Tuning.Key.meterScreenSpot)
        }
    }

    /// Remember the size the user dragged the meter to. If it already had a
    /// dragged spot, keep that in step too, so it doesn't jump.
    private func saveSize() {
        let box = NSSize(width: panel.frame.width, height: panel.frame.height - view.stripHeight)
        UserDefaults.standard.set([box.width, box.height], forKey: Tuning.Key.meterSize)
        let hasSpot = tuning.meterOnWindow ? tuning.meterWindowSpot != nil : tuning.meterScreenSpot != nil
        if hasSpot { saveSpot() }
    }

    func update(live: Live, tier: Int, message: (String, NSColor)?, shake: CGPoint, near anchor: NSRect?) {
        view.values = MeterValues(live)
        view.tier = tier
        view.message = message
        view.needsDisplay = true
        if anchor != nil { lastAnchor = anchor }
        if !panel.isVisible { panel.orderFrontRegardless() }
        // While you drag or resize it, the meter is yours: no placing, no shaking.
        if view.interacting { return }

        // The box holds the stats; a notice, if any, hangs in a strip below it.
        let box = tuning.meterSize ?? view.designSize(view.defaultShape)
        let strip = view.stripHeight(for: box)
        view.plannedStrip = strip
        let width = box.width, height = box.height + strip

        guard var screen = anchor.flatMap(FrontWindow.screen(for:)) ?? NSScreen.main else { return }
        var x: CGFloat, y: CGFloat
        if tuning.meterOnWindow, let anchor, let spot = tuning.meterWindowSpot {
            // Dragged spot on the docked window.
            x = anchor.minX + spot.x
            y = anchor.maxY + spot.y - strip
        } else if !tuning.meterOnWindow, let spot = tuning.meterScreenSpot {
            // Dragged spot on the screen: stays on whichever screen it was dropped on.
            screen = NSScreen.screens.first { $0.frame.contains(spot) } ?? screen
            x = spot.x
            y = spot.y - strip
        } else {
            // Docked: inside the window's edges. Otherwise: the screen's edges.
            let visible = screen.visibleFrame
            let base = tuning.meterOnWindow ? (anchor ?? visible) : visible
            let area = base.insetBy(dx: MeterPanel.margin, dy: MeterPanel.margin)
            let position = tuning.meterPosition
            x = position.isLeft ? area.minX : position.isRight ? area.maxX - width : area.midX - width / 2
            // At the top, grow downward when a notice appears.
            y = position.isTop ? area.maxY - height : area.minY
        }
        let visible = screen.visibleFrame
        // Never off the screen, even for a small window near an edge.
        x = min(max(x, visible.minX), visible.maxX - width)
        y = min(max(y, visible.minY), visible.maxY - height)
        let frame = NSRect(x: (x + shake.x).rounded(), y: (y + shake.y).rounded(), width: width, height: height)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    func hide() {
        if panel.isVisible { panel.orderOut(nil) }
    }
}

// MARK: - What the meter shows

/// The numbers on the meter, separate from `Live` so a sample can be built
/// to measure layouts.
private struct MeterValues {
    var wpm = 0, peak = 0, combo = 0
    var multiplier = 1.0, accuracy = 1.0
    var level = 0, xp = 0, span = 100, today = 0
    var rank = ""

    init() {}

    init(_ l: Live) {
        wpm = l.wpm; peak = l.sessionPeakWpm; combo = l.combo
        multiplier = l.multiplier; accuracy = l.accuracy
        level = l.level; xp = l.levelXp; span = l.levelSpan; today = l.today.chars
        rank = l.rank
    }

    /// Big values with the longest rank: lays out a meter that real values never outgrow.
    static let sample: MeterValues = {
        var v = MeterValues()
        v.wpm = 188; v.peak = 188; v.combo = 9999; v.multiplier = 5; v.accuracy = 1
        v.level = 30; v.xp = 99_999; v.span = 99_999; v.today = 999_999
        v.rank = ranks.map(\.1).max { $0.count < $1.count } ?? ""
        return v
    }()
}

/// The layouts. `MeterLayout.auto` picks one from the meter's shape.
enum MeterShape: CaseIterable {
    /// One long line.
    case singleLine
    /// Two lines.
    case wide
    /// A big WPM number on the left, the other stats in a column beside it.
    case compact
    /// Everything stacked, with a big WPM number on top.
    case square

    /// How Auto weighs a layout's text size: Single line leaves out the rank,
    /// XP numbers and today's count, so it has to fit noticeably bigger text
    /// to win over a layout that shows everything.
    var preference: CGFloat { self == .singleLine ? 0.75 : 1 }
}

/// One column of a layout: lines from top to bottom.
private struct Column {
    var lines: [NSAttributedString]
    /// Each line centered in the column, or left-aligned.
    var centered = false
    static let gap: CGFloat = 4

    var width: CGFloat { lines.map { $0.size().width }.max() ?? 0 }
    var height: CGFloat {
        lines.map { $0.size().height }.reduce(0, +) + Column.gap * CGFloat(max(0, lines.count - 1))
    }
}

// MARK: - Drawing, dragging and resizing

private final class MeterView: NSView {
    var values: MeterValues?
    var tier = 0
    var message: (String, NSColor)?
    var backgroundAlpha: CGFloat = 0.86
    var chosenLayout = MeterLayout.auto

    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    private let bold = NSFont.monospacedSystemFont(ofSize: 13, weight: .heavy)
    private let small = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private let big = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .heavy)
    private let huge = NSFont.monospacedDigitSystemFont(ofSize: 54, weight: .heavy)
    private let dim = NSColor(white: 0.62, alpha: 1)
    private let plain = NSColor(white: 0.9, alpha: 1)
    private let padX: CGFloat = 14, padY: CGFloat = 10, columnGap: CGFloat = 14
    private let messageFont: CGFloat = 12

    /// The shape used when no size has been dragged: the chosen layout, or two lines.
    var defaultShape: MeterShape { chosenLayout.shape ?? .wide }

    // MARK: Layout

    /// A layout at 1×, measured with the sample values: its size, and the
    /// width of each column (fixed, so columns don't shift as numbers change).
    private struct Design {
        let size: NSSize
        let widths: [CGFloat]
    }

    private func design(_ shape: MeterShape) -> Design {
        if let cached = designCache[shape] { return cached }
        let columns = self.columns(MeterValues.sample, shape, speed: plain)
        let widths = columns.map { $0.width.rounded(.up) }
        let w = widths.reduce(0, +) + columnGap * CGFloat(max(0, columns.count - 1))
        let h = columns.map(\.height).max() ?? 0
        let d = Design(size: NSSize(width: (w + padX * 2).rounded(.up), height: (h + padY * 2).rounded(.up)),
                       widths: widths)
        designCache[shape] = d
        return d
    }
    private var designCache: [MeterShape: Design] = [:]

    /// The natural size of a layout at 1×.
    func designSize(_ shape: MeterShape) -> NSSize { design(shape).size }

    /// The layout for a box: the chosen one, or (Auto) the one that fits the
    /// box with the biggest text.
    func shape(for box: NSSize) -> MeterShape {
        if let forced = chosenLayout.shape { return forced }
        return MeterShape.allCases.max {
            scale(for: box, $0) * $0.preference < scale(for: box, $1) * $1.preference
        }!
    }

    /// How much the layout is scaled to fill the box.
    private func scale(for box: NSSize, _ shape: MeterShape) -> CGFloat {
        let d = designSize(shape)
        return min(box.width / d.width, box.height / d.height)
    }

    /// Height of the notice strip under a box of this size; 0 with no notice.
    func stripHeight(for box: NSSize) -> CGFloat {
        guard let message else { return 0 }
        let s = min(1.5, max(0.85, scale(for: box, shape(for: box))))
        let text = messageText(message.0, message.1, size: messageFont * s)
        let rect = text.boundingRect(with: NSSize(width: max(40, box.width - padX * 2 * s), height: 1000),
                                     options: [.usesLineFragmentOrigin])
        let line = text.size().height
        return (min(rect.height, line * 3) + 8 * s).rounded(.up)
    }

    /// The strip height in use right now, from the current frame.
    var stripHeight: CGFloat { lastStrip }
    private var lastStrip: CGFloat = 0
    /// The strip height the panel sized itself for; used unless resizing.
    var plannedStrip: CGFloat = 0

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let radius = min(12, bounds.height / 2)
        NSColor(white: 0.07, alpha: backgroundAlpha).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        guard let values else { return }

        // Work out the box from the panel: everything above the notice strip.
        var strip: CGFloat = 0
        if message != nil {
            if interacting {
                // Resizing: solve for the strip with the box it leaves (one refinement is plenty).
                strip = stripHeight(for: bounds.size)
                strip = stripHeight(for: NSSize(width: bounds.width, height: max(10, bounds.height - strip)))
            } else {
                strip = plannedStrip
            }
        }
        lastStrip = strip
        let box = NSRect(x: 0, y: strip, width: bounds.width, height: max(10, bounds.height - strip))
        let shape = self.shape(for: box.size)
        let design = self.design(shape)
        let s = scale(for: box.size, shape)
        let speed = Speed.color(tier).map(nsColor) ?? plain

        // Draw the layout at 1× in its design box, scaled and centered in the box.
        // Each column is centered vertically.
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: box.midX - design.size.width * s / 2, yBy: box.midY - design.size.height * s / 2)
        t.scale(by: s)
        t.concat()
        var x = padX
        for (column, width) in zip(columns(values, shape, speed: speed), design.widths) {
            var y = (design.size.height + column.height) / 2
            for line in column.lines {
                let size = line.size()
                y -= size.height
                line.draw(at: NSPoint(x: column.centered ? x + (width - size.width) / 2 : x, y: y))
                y -= Column.gap
            }
            x += width + columnGap
        }
        NSGraphicsContext.restoreGraphicsState()

        if let (msg, color) = message, strip > 0 {
            let ms = min(1.5, max(0.85, s))
            let rect = NSRect(x: padX * ms, y: 4 * ms, width: bounds.width - padX * 2 * ms, height: strip - 6 * ms)
            messageText(msg, color, size: messageFont * ms)
                .draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    /// The columns of a layout, left to right.
    private func columns(_ v: MeterValues, _ shape: MeterShape, speed: NSColor) -> [Column] {
        let purple = NSColor.systemPurple
        let comboColor = v.combo >= 25 ? NSColor.systemPink : plain
        let xpFraction = Double(v.xp) / Double(max(1, v.span))
        let acc = Int((v.accuracy * 100).rounded())

        switch shape {
        case .singleLine:
            let line = NSMutableAttributedString()
            line.append(text(String(format: "%3d", v.wpm), bold, speed))
            line.append(text(" WPM ", font, speed))
            line.append(bar(Double(v.wpm) / 100, width: 10, color: speed))
            line.append(text("  COMBO \(v.combo) ", bold, comboColor))
            line.append(text(String(format: "×%.1f", v.multiplier), font, dim))
            line.append(text("  ACC \(acc)%", font, dim))
            line.append(text("  LV \(v.level) ", bold, purple))
            line.append(bar(xpFraction, width: 8, color: purple))
            return [Column(lines: [line])]

        case .wide:
            let one = NSMutableAttributedString()
            one.append(text(String(format: "%3d", v.wpm), bold, speed))
            one.append(text(" WPM ", font, speed))
            one.append(bar(Double(v.wpm) / 100, width: 18, color: speed))
            one.append(text("  peak \(v.peak)", font, dim))
            one.append(text("   COMBO \(v.combo) ", bold, comboColor))
            one.append(text(String(format: "×%.1f", v.multiplier), font, dim))
            one.append(text("   ACC \(acc)%", font, dim))
            let two = NSMutableAttributedString()
            two.append(text("LV \(v.level) ", bold, purple))
            two.append(text("\(v.rank) ", font, plain))
            two.append(bar(xpFraction, width: 18, color: purple))
            two.append(text("  \(group(v.xp))/\(group(v.span)) XP", font, dim))
            two.append(text("   today \(group(v.today)) chars", font, dim))
            return [Column(lines: [one, two])]

        case .compact:
            let wpmBar = NSMutableAttributedString(attributedString: bar(Double(v.wpm) / 100, width: 12, color: speed))
            wpmBar.append(text(" peak \(v.peak)", small, dim))
            let combo = NSMutableAttributedString(attributedString: text("COMBO \(v.combo) ", bold, comboColor))
            combo.append(text(String(format: "×%.1f", v.multiplier), font, dim))
            combo.append(text("  ACC \(acc)%", font, dim))
            let level = NSMutableAttributedString(attributedString: text("LV \(v.level) ", bold, purple))
            level.append(text(v.rank, font, plain))
            let xpBar = NSMutableAttributedString(attributedString: bar(xpFraction, width: 12, color: purple))
            xpBar.append(text(" \(group(v.xp))/\(group(v.span)) XP", small, dim))
            return [
                Column(lines: [text("\(v.wpm)", huge, speed), text("WPM", small, dim)], centered: true),
                Column(lines: [wpmBar, combo, level, xpBar, text("today \(group(v.today)) chars", small, dim)]),
            ]

        case .square:
            let combo = NSMutableAttributedString(attributedString: text("COMBO \(v.combo) ", bold, comboColor))
            combo.append(text(String(format: "×%.1f", v.multiplier), font, dim))
            let level = NSMutableAttributedString(attributedString: text("LV \(v.level) ", bold, purple))
            level.append(text(v.rank, font, plain))
            return [Column(lines: [
                text("\(v.wpm)", big, speed),
                text("WPM · peak \(v.peak)", small, dim),
                bar(Double(v.wpm) / 100, width: 12, color: speed),
                combo,
                text("ACC \(acc)%", font, dim),
                level,
                bar(xpFraction, width: 12, color: purple),
                text("\(group(v.xp))/\(group(v.span)) XP · today \(group(v.today))", small, dim),
            ], centered: true)]
        }
    }

    private func messageText(_ s: String, _ color: NSColor, size: CGFloat) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium),
            .foregroundColor: color,
        ])
    }

    private func text(_ s: String, _ font: NSFont, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    }

    private func bar(_ fraction: Double, width: Int, color: NSColor) -> NSAttributedString {
        let filled = Int((min(1, max(0, fraction)) * Double(width)).rounded())
        let out = NSMutableAttributedString(attributedString: text("▕", font, dim))
        out.append(text(String(repeating: "█", count: filled), font, color))
        out.append(text(String(repeating: "░", count: width - filled), font, NSColor(white: 0.3, alpha: 1)))
        out.append(text("▏", font, dim))
        return out
    }

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func group(_ n: Int) -> String {
        MeterView.grouping.string(from: NSNumber(value: n)) ?? String(n)
    }

    // MARK: Moving and resizing

    /// True while the user drags or resizes the meter.
    var interacting: Bool { mode != nil }
    var onMoved: (() -> Void)?
    var onResized: (() -> Void)?

    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1), right = Edges(rawValue: 2)
        static let top = Edges(rawValue: 4), bottom = Edges(rawValue: 8)
    }
    private enum Mode { case move, resize(Edges) }
    private var mode: Mode?
    private var startMouse: NSPoint = .zero
    private var startFrame: NSRect = .zero
    /// How close to an edge counts as grabbing it.
    private let grip: CGFloat = 8
    private let minSize = NSSize(width: 90, height: 26)
    private let maxSize = NSSize(width: 2400, height: 1200)

    // React to the very first click, without bringing our app forward.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        let b = bounds
        addCursorRect(b.insetBy(dx: grip, dy: grip), cursor: .openHand)
        addCursorRect(NSRect(x: 0, y: 0, width: grip, height: b.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: b.maxX - grip, y: 0, width: grip, height: b.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: grip, y: 0, width: b.width - grip * 2, height: grip), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: grip, y: b.maxY - grip, width: b.width - grip * 2, height: grip), cursor: .resizeUpDown)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    private func edges(at p: NSPoint) -> Edges {
        var e: Edges = []
        if p.x <= grip { e.insert(.left) }
        if p.x >= bounds.maxX - grip { e.insert(.right) }
        if p.y <= grip { e.insert(.bottom) }
        if p.y >= bounds.maxY - grip { e.insert(.top) }
        return e
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let e = edges(at: convert(event.locationInWindow, from: nil))
        mode = e.isEmpty ? .move : .resize(e)
        startMouse = NSEvent.mouseLocation
        startFrame = window.frame
        if e.isEmpty { NSCursor.closedHand.push() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mode, let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x, dy = mouse.y - startMouse.y
        switch mode {
        case .move:
            window.setFrameOrigin(NSPoint(x: startFrame.minX + dx, y: startFrame.minY + dy))
        case .resize(let e):
            var f = startFrame
            if e.contains(.right) { f.size.width = startFrame.width + dx }
            if e.contains(.left) { f.size.width = startFrame.width - dx }
            if e.contains(.top) { f.size.height = startFrame.height + dy }
            if e.contains(.bottom) { f.size.height = startFrame.height - dy }
            f.size.width = min(max(f.width, minSize.width), maxSize.width)
            f.size.height = min(max(f.height, minSize.height + lastStrip), maxSize.height)
            // Left and bottom edges move the origin; the opposite edge stays put.
            if e.contains(.left) { f.origin.x = startFrame.maxX - f.width }
            if e.contains(.bottom) { f.origin.y = startFrame.maxY - f.height }
            window.setFrame(f, display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let mode, let window else { return }
        self.mode = nil
        switch mode {
        case .move:
            NSCursor.pop()
            // A plain click without moving doesn't pin the meter.
            if window.frame.origin != startFrame.origin { onMoved?() }
        case .resize:
            if window.frame != startFrame { onResized?() }
        }
    }
}
