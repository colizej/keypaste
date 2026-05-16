import AppKit
import Foundation

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
    private var store: TriggerStore?
    private var engine: Engine?
    private var paste: SystemPasteStrategy?
    private var tap: EventTap?
    private var statusBar: StatusBarController?
    private var mainWindow: MainWindowController?
    private var workspaceObserver: NSObjectProtocol?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("KeyPaste launched")

        let store: TriggerStore
        do {
            store = try TriggerStore()
        } catch {
            showFatalAlert(message: "Could not open trigger store: \(error)")
            return
        }
        self.store = store

        let paste = SystemPasteStrategy()
        self.paste = paste

        let engine = Engine(paste: paste,
                            renderContext: AppDelegate.contextProvider)
        self.engine = engine

        // Future store.save() calls (UI edits) refresh the matcher.
        store.onSave = { [weak engine] file in
            engine?.setTriggers(file.triggers)
        }

        // Initial load — may auto-migrate from legacy v1 on first run.
        do {
            let initial = try store.load()
            engine.setTriggers(initial.triggers)
            Logger.info("Loaded \(initial.triggers.count) trigger(s)")
        } catch {
            Logger.error("Initial trigger load failed: \(error)")
        }

        let mainWindow = MainWindowController(store: store)
        self.mainWindow = mainWindow

        let bar = StatusBarController(
            triggersFolderURL: store.directoryURL,
            onEditTriggers: { [weak mainWindow] in mainWindow?.show() }
        )
        self.statusBar = bar

        // App-switch and secure-input transitions reset Engine state so
        // a half-typed buffer in app A can't carry into app B.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak engine] _ in engine?.reset() }

        // Start the event tap, prompting for accessibility if needed.
        do {
            let tap = EventTap(engine: engine)
            try tap.start()
            self.tap = tap
        } catch EventTap.TapError.notAccessibilityTrusted {
            _ = PermissionsChecker.isAccessibilityTrusted(prompt: true)
            showAccessibilityAlert()
        } catch {
            showFatalAlert(message: "Event tap failed: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        tap?.stop()
        Logger.info("KeyPaste terminating")
    }

    // Captures clipboard + username + date at the moment a trigger fires.
    // Free function (not a method) so we can pass it as a value without
    // worrying about MainActor isolation.
    private static let contextProvider: () -> Template.Context = {
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        return Template.Context(clipboard: clipboard,
                                username: NSUserName(),
                                date: Date())
    }

    @MainActor
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "KeyPaste needs Accessibility access"
        alert.informativeText = """
        Open System Settings → Privacy & Security → Accessibility and \
        enable KeyPaste. macOS only loads this permission at process \
        start, so quit and relaunch KeyPaste afterwards.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showFatalAlert(message: String) {
        Logger.error(message)
        let alert = NSAlert()
        alert.messageText = "KeyPaste failed to start"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
