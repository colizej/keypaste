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
// while the window is visible and reverts to .accessory in
// windowWillClose. orderFrontRegardless() and the explicit
// setContentSize after assigning contentViewController are belt-and-
// suspenders for NSHostingController not always forcing a layout pass
// on first show.

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    let viewModel: TriggerListViewModel
    private let window: NSWindow

    private static let contentSize = NSSize(width: 760, height: 480)

    init(store: TriggerStore) {
        self.viewModel = TriggerListViewModel(store: store)

        let root = TriggerListView(vm: viewModel)
        let host = NSHostingController(rootView: root)

        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyPaste — Triggers"
        window.minSize = Self.contentSize
        window.contentViewController = host
        window.setContentSize(Self.contentSize)
        window.center()
        window.setFrameAutosaveName("KeyPasteMain")
        window.isReleasedWhenClosed = false

        super.init()
        window.delegate = self
    }

    func show() {
        Logger.info("MainWindow.show invoked")
        viewModel.reload()
        ActivationPolicy.windowOpened()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        Logger.info("MainWindow closed")
        ActivationPolicy.windowClosed()
    }
}
