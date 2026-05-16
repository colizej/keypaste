import AppKit
import SwiftUI

// NSWindow host for the TriggerListView. The status-bar menu's
// "Edit Triggers…" item routes through `show()`. We keep a single
// window for the app's lifetime so window state (size, search filter,
// selection) survives close-then-reopen.

@MainActor
final class MainWindowController {
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
    }

    func show() {
        viewModel.reload()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
