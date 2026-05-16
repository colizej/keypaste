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
        Logger.info("KeyPaste launched (pid \(ProcessInfo.processInfo.processIdentifier))")

        let store: TriggerStore
        do {
            store = try TriggerStore()
        } catch {
            // NSAlert.runModal is fatal here: an .accessory app can't show
            // a modal alert before any activation, so calling it would
            // block the runloop and freeze the status-bar menu. Log and
            // bail; the user sees an empty menu bar and the failure in
            // os_log.
            Logger.error("Could not open trigger store: \(error)")
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
            onEditTriggers: { [weak mainWindow] in mainWindow?.show() },
            onPauseChanged: { [weak engine] paused in engine?.setPaused(paused) }
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
        // NB: do NOT runModal an NSAlert here — an .accessory-policy app
        // hasn't activated yet, so a modal session would block the
        // runloop and freeze the status-bar menu. The system prompt from
        // AXIsProcessTrustedWithOptions is the user-facing UI; status bar
        // stays responsive so the user can quit + retry.
        do {
            let tap = EventTap(engine: engine)
            try tap.start()
            self.tap = tap
            Logger.info("Event tap running")
        } catch EventTap.TapError.notAccessibilityTrusted {
            _ = PermissionsChecker.isAccessibilityTrusted(prompt: true)
            Logger.warning("Accessibility not granted — enable KeyPaste in System Settings → Privacy & Security → Accessibility, then quit and relaunch.")
        } catch {
            Logger.error("Event tap failed: \(error)")
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

}
