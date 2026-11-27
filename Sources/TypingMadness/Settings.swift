// On/off switches from the menu, remembered in UserDefaults.

import Foundation

struct Settings {
    private let defaults = UserDefaults.standard

    private func flag(_ key: String, default value: Bool = true) -> Bool {
        defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
    }

    var tint: Bool {
        get { flag("tint") }
        nonmutating set { defaults.set(newValue, forKey: "tint") }
    }
    var border: Bool {
        get { flag("border") }
        nonmutating set { defaults.set(newValue, forKey: "border") }
    }
    var flash: Bool {
        get { flag("flash") }
        nonmutating set { defaults.set(newValue, forKey: "flash") }
    }
    var badges: Bool {
        get { flag("badges") }
        nonmutating set { defaults.set(newValue, forKey: "badges") }
    }
    var fireworks: Bool {
        get { flag("fireworks") }
        nonmutating set { defaults.set(newValue, forKey: "fireworks") }
    }
    var shake: Bool {
        get { flag("shake") }
        nonmutating set { defaults.set(newValue, forKey: "shake") }
    }
    /// Asked for Accessibility once already, so don't pop the prompt every launch.
    var askedAccessibility: Bool {
        get { flag("askedAccessibility", default: false) }
        nonmutating set { defaults.set(newValue, forKey: "askedAccessibility") }
    }
    var meter: Bool {
        get { flag("meter") }
        nonmutating set { defaults.set(newValue, forKey: "meter") }
    }
    var paused: Bool {
        get { flag("paused", default: false) }
        nonmutating set { defaults.set(newValue, forKey: "paused") }
    }
}
