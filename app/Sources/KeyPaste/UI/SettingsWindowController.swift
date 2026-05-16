import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private static let contentSize = NSSize(width: 480, height: 620)

    init(store: SettingsStore,
         onInstallPack: @escaping (SnippetPack) -> SnippetPacks.InstallResult) {
        let view = SettingsView(store: store, onInstallPack: onInstallPack)
        let host = NSHostingController(rootView: view)

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
