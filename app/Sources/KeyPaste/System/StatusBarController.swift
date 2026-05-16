import AppKit
import Foundation

// NSStatusItem in the menu bar. NSObject subclass so the menu items can
// route through @objc selectors back to our handlers.
//
// Tray icon: a small SF Symbol coloured to match the brand.
//   circle.fill  → engine running
//   circle       → engine paused
// The colour is sampled once from AppIcon.icns at startup (32×32 average
// of opaque pixels) so the dot tracks whatever artwork ships with the
// .app. macOS 13 NSImage.SymbolConfiguration(paletteColors:) handles the
// tint without us touching pixels at runtime.

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let triggersFolderURL: URL
    private let onEditTriggers: () -> Void
    private let onOpenSettings: () -> Void
    private let onPauseChanged: (Bool) -> Void
    private let onExport: () -> Void
    private let onImport: () -> Void
    private let onOpenStats: () -> Void

    private var isPaused = false
    private var pauseMenuItem: NSMenuItem!
    private lazy var iconTint: NSColor = Self.sampleBrandColor()

    init(triggersFolderURL: URL,
         onEditTriggers: @escaping () -> Void,
         onOpenSettings: @escaping () -> Void,
         onPauseChanged: @escaping (Bool) -> Void,
         onExport: @escaping () -> Void,
         onImport: @escaping () -> Void,
         onOpenStats: @escaping () -> Void) {
        self.triggersFolderURL = triggersFolderURL
        self.onEditTriggers = onEditTriggers
        self.onOpenSettings = onOpenSettings
        self.onPauseChanged = onPauseChanged
        self.onExport = onExport
        self.onImport = onImport
        self.onOpenStats = onOpenStats
        self.statusItem = NSStatusBar.system
            .statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        statusItem.button?.toolTip = "KeyPaste"
        refreshIcon()

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

        let importItem = NSMenuItem(title: "Import Triggers…",
                                    action: #selector(handleImport),
                                    keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)

        let exportItem = NSMenuItem(title: "Export Triggers…",
                                    action: #selector(handleExport),
                                    keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(.separator())

        let stats = NSMenuItem(title: "Statistics…",
                               action: #selector(handleOpenStats),
                               keyEquivalent: "")
        stats.target = self
        menu.addItem(stats)

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(handleOpenSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

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
        refreshIcon()
        onPauseChanged(isPaused)
    }

    // The dot is rebuilt every state change so the colour stays correct
    // even if the user later swaps AppIcon and rebuilds without
    // restarting (the lazy iconTint still holds the previous value, but
    // a relaunch is fine for an unsigned dev build).
    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let symbolName = isPaused ? "circle" : "circle.fill"
        let base = NSImage(systemSymbolName: symbolName,
                           accessibilityDescription: isPaused
                                                     ? "KeyPaste (paused)"
                                                     : "KeyPaste")
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(.init(paletteColors: [iconTint]))
        let image = base?.withSymbolConfiguration(config)
        image?.isTemplate = false
        button.image = image
    }

    // Average opaque pixels of AppIcon at a small size. The 1×1
    // downscale trick suffers from washed-out averages on icons with
    // alpha edges; 32×32 + alpha-aware mean gives a representative
    // brand colour and falls back to controlAccent if anything fails.
    private static func sampleBrandColor() -> NSColor {
        let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        let side = 32
        let size = NSSize(width: side, height: side)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            return .controlAccentColor
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        appIcon.draw(in: NSRect(origin: .zero, size: size),
                     from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, count: CGFloat = 0
        for y in 0..<side {
            for x in 0..<side {
                guard let pixel = bitmap.colorAt(x: x, y: y) else { continue }
                let opaque = pixel.usingColorSpace(.deviceRGB) ?? pixel
                if opaque.alphaComponent < 0.5 { continue }
                r += opaque.redComponent
                g += opaque.greenComponent
                b += opaque.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return .controlAccentColor }
        return NSColor(red: r / count, green: g / count, blue: b / count,
                       alpha: 1.0)
    }

    @objc private func handleOpenFolder() {
        NSWorkspace.shared.open(triggersFolderURL)
    }

    @objc private func handleOpenSettings() {
        onOpenSettings()
    }

    @objc private func handleImport() {
        onImport()
    }

    @objc private func handleExport() {
        onExport()
    }

    @objc private func handleOpenStats() {
        onOpenStats()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
