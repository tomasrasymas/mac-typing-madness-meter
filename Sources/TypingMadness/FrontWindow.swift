// Where the window you're typing in is.
//
// Uses the window server's window list, which gives every window's owner and
// bounds without Screen Recording or Accessibility permission (only window
// titles are withheld, and we don't need them). The list is ordered front to
// back, so the first normal window owned by the frontmost app is the active one.

import AppKit

enum FrontWindow {
    struct Info: Equatable {
        /// In Cocoa screen coordinates (origin at the bottom-left of the main screen).
        var frame: NSRect
        var bundleId: String?
        var pid: pid_t
    }

    static func current() -> Info? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }
        let pid = app.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in list {
            guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= 120, rect.height >= 80 else { continue }
            return Info(frame: toCocoa(rect), bundleId: app.bundleIdentifier, pid: pid)
        }
        return nil
    }

    /// Quartz window bounds (origin top-left of the main screen) -> Cocoa.
    static func toCocoa(_ r: CGRect) -> NSRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
    }

    /// The screen showing most of `frame`.
    static func screen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            a.frame.intersection(frame).area < b.frame.intersection(frame).area
        } ?? NSScreen.main
    }
}

extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
