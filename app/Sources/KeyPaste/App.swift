import AppKit

// Entry point. Sprint 1 will wire up the status bar item, accessibility
// permission check, CGEventTap, and the SwiftUI editor window.

@main
struct KeyPasteMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon

        let delegate = AppDelegate()
        app.delegate = delegate

        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("KeyPaste launched (scaffold; engine not yet wired)")
        // Sprint 1: StatusBarController().install()
        // Sprint 1: PermissionsChecker().ensureAccessibility()
        // Sprint 1: EventTap().start { keyEvent in Engine.shared.consume(keyEvent) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("KeyPaste terminating")
    }
}
