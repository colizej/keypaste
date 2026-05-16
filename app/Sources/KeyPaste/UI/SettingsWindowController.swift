import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private static let contentSize = NSSize(width: 420, height: 320)

    init(store: SettingsStore) {
        let host = NSHostingController(rootView: SettingsView(store: store))

        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyPaste Settings"
        window.contentViewController = host
        window.setContentSize(Self.contentSize)
        window.center()
        window.setFrameAutosaveName("KeyPasteSettings")
        window.isReleasedWhenClosed = false

        super.init()
        window.delegate = self
    }

    func show() {
        Logger.info("SettingsWindow.show invoked")
        ActivationPolicy.windowOpened()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        Logger.info("SettingsWindow closed")
        ActivationPolicy.windowClosed()
    }
}
