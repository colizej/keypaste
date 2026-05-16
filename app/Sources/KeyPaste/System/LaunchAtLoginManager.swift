import Foundation
import ServiceManagement

// Thin wrapper over SMAppService.mainApp (macOS 13+). The system
// remembers the toggle across reboots without us writing anything —
// SettingsStore.launchAtLogin is the user-facing mirror, this is the
// actual registration sink. Run register/unregister on the main thread
// so SMAppService doesn't complain about thread context.

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                    Logger.info("LaunchAtLogin: registered")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    Logger.info("LaunchAtLogin: unregistered")
                }
            }
        } catch {
            // Common failures: app not in /Applications, sandbox issues,
            // missing entitlements. Log and continue; the UI toggle in
            // SettingsStore will reflect the user's intent but the
            // system won't honour it until the underlying issue is fixed.
            Logger.error("LaunchAtLogin toggle failed: \(error)")
        }
    }
}
