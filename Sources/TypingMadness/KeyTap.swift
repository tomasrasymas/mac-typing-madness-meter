// System-wide keystroke counter: a listen-only CGEventTap on key-down events.
//
// Needs Input Monitoring permission (System Settings › Privacy & Security ›
// Input Monitoring). Only the *kind* of key is reported (character, backspace,
// enter, other); the text typed is never kept. Password fields turn on
// macOS secure input, which hides keys from every tap, including this one.

import AppKit
import MadnessCore

final class KeyTap {
    var onKey: ((KeyClass) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var running: Bool { tap != nil }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Show the system prompt (once) asking for Input Monitoring.
    static func requestPermission() { _ = CGRequestListenEventAccess() }

    /// Start listening; false without permission.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ event: CGEvent) {
        if let cls = KeyTap.classify(event) { onKey?(cls) }
    }

    /// What kind of key this is; nil for key repeats (holding a key isn't typing).
    static func classify(_ event: CGEvent) -> KeyClass? {
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) { return .other } // shortcuts
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 51, 117: return .backspace // delete, forward delete
        case 36, 76: return .enter // return, keypad enter
        default: break
        }
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return .other }
        let c = chars[0]
        // Printable, and not a function/arrow key (those live in 0xF700...0xF8FF).
        if c >= 0x20 && c != 0x7F && !(0xF700...0xF8FF).contains(c) { return .char }
        return .other
    }
}

private func keyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            tap.reenable()
        case .keyDown:
            tap.handle(event)
        default:
            break
        }
    }
    return Unmanaged.passUnretained(event)
}
