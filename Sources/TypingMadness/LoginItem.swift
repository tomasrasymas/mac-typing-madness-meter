// "Start at login": registers the app as a login item with macOS
// (System Settings › General › Login Items). macOS keeps this itself, so it
// isn't stored in our settings.

import Foundation
import ServiceManagement

final class LoginItem: ObservableObject {
    @Published private(set) var enabled = LoginItem.isEnabled
    /// Why the last change didn't work, or what's still needed.
    @Published private(set) var note: String?

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            note = nil
        } catch {
            note = Bundle.main.bundlePath.hasSuffix(".app")
                ? "macOS refused: \(error.localizedDescription)"
                : "Only works for the app bundle, not `swift run`. Build it with scripts/bundle.sh."
        }
        refresh()
    }

    func refresh() {
        enabled = LoginItem.isEnabled
        if SMAppService.mainApp.status == .requiresApproval {
            note = "Approve Typing Madness in System Settings › General › Login Items."
        }
    }
}
