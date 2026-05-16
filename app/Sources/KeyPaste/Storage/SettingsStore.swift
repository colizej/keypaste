import Foundation
import SwiftUI

// App preferences. UserDefaults-backed for idiom + simplicity; we
// migrate to a JSON file if we ever need to ship settings between
// devices, but for local prefs UserDefaults is the macOS norm.
//
// ObservableObject so the SettingsView form rebinds automatically. The
// init takes a UserDefaults so tests can pass UserDefaults(suiteName:)
// for isolation.

@MainActor
final class SettingsStore: ObservableObject {
    static let launchAtLoginKey      = "launchAtLogin"
    static let pasteRestoreDelayKey  = "pasteRestoreDelay"

    static let defaultPasteRestoreDelay: Double = 0.25
    static let pasteRestoreDelayRange: ClosedRange<Double> = 0.05...1.0

    private let defaults: UserDefaults

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Self.launchAtLoginKey) }
    }

    @Published var pasteRestoreDelay: Double {
        didSet {
            let clamped = min(max(pasteRestoreDelay,
                                  Self.pasteRestoreDelayRange.lowerBound),
                              Self.pasteRestoreDelayRange.upperBound)
            if clamped != pasteRestoreDelay {
                pasteRestoreDelay = clamped
                return
            }
            defaults.set(clamped, forKey: Self.pasteRestoreDelayKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
        let raw = defaults.object(forKey: Self.pasteRestoreDelayKey) as? Double
        self.pasteRestoreDelay = raw ?? Self.defaultPasteRestoreDelay
    }
}
