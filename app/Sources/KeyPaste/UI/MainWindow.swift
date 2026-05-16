import AppKit
import SwiftUI

// NSWindow host for the TriggerListView. The status-bar menu's
// "Edit Triggers…" routes through `show()`. We keep a single window
// for the app's lifetime so its size, search filter, and selection
// survive close-then-reopen.
//
// Activation-policy dance: NSApp starts in .accessory so KeyPaste
// stays a menu-bar app with no Dock icon. But .accessory windows
// don't get foregrounded by activate(ignoringOtherApps:) — the editor
// would open invisibly behind the active app. show() flips to .regular
// while the window is visible and reverts to .accessory when it closes,
// via the NSWindowDelegate hook below.

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    let viewModel: TriggerListViewModel
    private let window: NSWindow

    init(store: TriggerStore) {
        self.viewModel = TriggerListViewModel(store: store)

        let root = TriggerListView(vm: viewModel)
        let host = NSHostingController(rootView: root)

        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyPaste — Triggers"
        window.contentViewController = host
        window.center()
        window.setFrameAutosaveName("KeyPasteMain")
        window.isReleasedWhenClosed = false

        super.init()
        window.delegate = self
    }

    func show() {
        viewModel.reload()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
