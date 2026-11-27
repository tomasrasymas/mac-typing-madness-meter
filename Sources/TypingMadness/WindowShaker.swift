// Shakes the window you're typing in by nudging its position through the
// Accessibility API, then puts it back exactly where it was.
//
// Needs Accessibility permission (System Settings › Privacy & Security ›
// Accessibility). Without it, `update` returns false and the app shakes only
// its own effects instead.

import AppKit
import ApplicationServices

final class WindowShaker {
    private var window: AXUIElement?
    private var pid: pid_t = 0
    /// Where the window sits when not shaking, in Quartz coordinates (top-left origin).
    private var home: CGPoint = .zero
    private var size: CGSize = .zero
    /// Whether we've nudged the window away from `home` since taking hold of it.
    private var moved = false
    /// Windows that refused to move (full screen, fixed panels): left alone.
    private var stuck: AXUIElement?

    /// The current nudge, in Cocoa direction (y up).
    private(set) var offset: CGPoint = .zero
    /// True when shaking was wanted but Accessibility isn't allowed.
    private(set) var needsPermission = false

    static var trusted: Bool { AXIsProcessTrusted() }
    /// `trusted`, rechecked about once a second rather than every frame.
    private var trustedCache = false
    private var trustCheck = 0
    private var isTrusted: Bool {
        if trustCheck % 30 == 0 { trustedCache = WindowShaker.trusted }
        trustCheck += 1
        return trustedCache
    }

    /// Shows the system prompt that points to the Accessibility settings.
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// The window's resting frame in Cocoa coordinates, while shaking.
    var homeFrame: NSRect? {
        guard window != nil else { return nil }
        return FrontWindow.toCocoa(CGRect(origin: home, size: size))
    }

    /// Shake app `pid`'s focused window by up to `amplitude` points this
    /// frame. That's the window the effects are on: usually the frontmost
    /// app's, or the one behind our Settings window. Below 0.5 it puts the
    /// window back. Returns whether the real window is shaking.
    @discardableResult
    func update(amplitude: Double, pid target: pid_t) -> Bool {
        guard amplitude >= 0.5 else {
            needsPermission = false
            stop()
            return false
        }
        needsPermission = !isTrusted
        if needsPermission {
            stop()
            return false
        }
        // A mouse button is down: you may be dragging or resizing the window.
        // Let go without moving it back, so wherever you put it becomes its home.
        if NSEvent.pressedMouseButtons != 0 {
            release()
            return false
        }
        // Moved on to another app or window: put the old one back first.
        if window != nil, !isStillFocused(pid: target) { stop() }
        if window == nil, !begin(pid: target) { return false }
        guard let window else { return false }

        // Never re-read the position while shaking: apps report it late, and
        // taking a late shaken position as home makes the window drift.
        let a = CGFloat(amplitude)
        let nudge = CGPoint(x: .random(in: -a...a), y: .random(in: -a...a) * 0.6)
        let target = CGPoint(x: home.x + nudge.x, y: home.y + nudge.y)
        switch setPosition(of: window, to: target) {
        case .success:
            break
        case .cannotComplete:
            // The app is busy: skip this frame, try again next one.
            return false
        case .apiDisabled:
            needsPermission = true
            stop()
            return false
        default:
            // This window can't be moved (full screen, fixed panel): leave it be.
            stuck = window
            stop()
            return false
        }
        moved = true
        offset = CGPoint(x: nudge.x, y: -nudge.y)
        return true
    }

    /// Put the window back exactly where it was and let go of it.
    func stop() {
        if let window, moved { setPosition(of: window, to: home) }
        release()
    }

    /// Let go of the window without moving it.
    private func release() {
        window = nil
        moved = false
        offset = .zero
    }

    private func begin(pid target: pid_t) -> Bool {
        guard target != getpid(), // never our own windows
              let focused = focusedWindow(pid: target),
              stuck.map({ !CFEqual($0, focused) }) ?? true,
              let pos = position(of: focused),
              let size = size(of: focused) else { return false }
        window = focused
        pid = target
        home = pos
        self.size = size
        return true
    }

    private func isStillFocused(pid target: pid_t) -> Bool {
        guard let window, target == pid,
              let focused = focusedWindow(pid: pid) else { return false }
        return CFEqual(window, focused)
    }

    private func focusedWindow(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        // Never let a busy app stall the 30 fps loop.
        AXUIElementSetMessagingTimeout(app, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement
        AXUIElementSetMessagingTimeout(window, 0.05)
        return window
    }

    private func position(of window: AXUIElement) -> CGPoint? {
        guard let value = axValue(window, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func size(of window: AXUIElement) -> CGSize? {
        guard let value = axValue(window, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    @discardableResult
    private func setPosition(of window: AXUIElement, to point: CGPoint) -> AXError {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }
}
