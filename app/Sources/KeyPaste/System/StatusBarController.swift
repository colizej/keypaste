import AppKit
import Foundation

// NSStatusItem in the menu bar. NSObject subclass so the menu items can
// route through @objc selectors back to our handlers.
//
// Icon: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath) reads
// AppIcon.icns from the .app bundle and we downscale to 18×18 for the
// menu bar. isTemplate stays false because the source is a colored
// icon, not a B&W glyph — macOS won't tint it. If the artwork ever
// becomes monochrome, flip isTemplate.

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let triggersFolderURL: URL
    private let onEditTriggers: () -> Void
    private let onPauseChanged: (Bool) -> Void

    private var isPaused = false
    private var pauseMenuItem: NSMenuItem!

    init(triggersFolderURL: URL,
         onEditTriggers: @escaping () -> Void,
         onPauseChanged: @escaping (Bool) -> Void) {
        self.triggersFolderURL = triggersFolderURL
        self.onEditTriggers = onEditTriggers
        self.onPauseChanged = onPauseChanged
        self.statusItem = NSStatusBar.system
            .statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            button.image = icon
            button.toolTip = "KeyPaste"
        }

        let menu = NSMenu()

        let edit = NSMenuItem(title: "Edit Triggers…",
                              action: #selector(handleEdit),
                              keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)

        let pause = NSMenuItem(title: "Pause",
                               action: #selector(handleTogglePause),
                               keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        pauseMenuItem = pause

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

    @objc private func handleTogglePause() {
        isPaused.toggle()
        pauseMenuItem.title = isPaused ? "Resume" : "Pause"
        statusItem.button?.appearsDisabled = isPaused
        onPauseChanged(isPaused)
    }

    @objc private func handleOpenFolder() {
        NSWorkspace.shared.open(triggersFolderURL)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
