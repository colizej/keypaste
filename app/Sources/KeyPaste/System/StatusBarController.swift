import AppKit
import Foundation

// NSStatusItem in the menu bar. NSObject subclass so the menu items can
// route through @objc selectors back to our handlers.
//
// Pause/Resume is intentionally absent in Sprint 1 — adding it cleanly
// needs an "enabled" flag on Engine plus state on EventTap, which is
// noise on top of the v1 goal of "trigger expansion works at all".
// Add it in Sprint 2 alongside Settings.

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let triggersFolderURL: URL
    private let onEditTriggers: () -> Void

    init(triggersFolderURL: URL,
         onEditTriggers: @escaping () -> Void) {
        self.triggersFolderURL = triggersFolderURL
        self.onEditTriggers = onEditTriggers
        self.statusItem = NSStatusBar.system
            .statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "keyboard",
                                accessibilityDescription: "KeyPaste")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "KeyPaste"
        }

        let menu = NSMenu()

        let edit = NSMenuItem(title: "Edit Triggers…",
                              action: #selector(handleEdit),
                              keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)

        let open = NSMenuItem(title: "Open Triggers Folder",
                              action: #selector(handleOpenFolder),
                              keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit KeyPaste",
                              action: #selector(handleQuit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func handleEdit() {
        onEditTriggers()
    }

    @objc private func handleOpenFolder() {
        NSWorkspace.shared.open(triggersFolderURL)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
