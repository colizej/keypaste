import AppKit
import SwiftUI

@MainActor
final class StatsWindowController: NSObject, NSWindowDelegate {
    private let triggerStore: TriggerStore
    private let statsStore: StatsStore
    private let window: NSWindow
    private static let contentSize = NSSize(width: 640, height: 480)
    private var host: NSHostingController<StatsView>!

    init(triggerStore: TriggerStore, statsStore: StatsStore) {
        self.triggerStore = triggerStore
        self.statsStore = statsStore

        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyPaste — Statistics"
        window.setContentSize(Self.contentSize)
        window.center()
        window.setFrameAutosaveName("KeyPasteStats")
        window.isReleasedWhenClosed = false

        super.init()
        host = NSHostingController(rootView: buildView())
        window.contentViewController = host
        window.delegate = self
    }

    func show() {
        Logger.info("StatsWindow.show invoked")
        host.rootView = buildView()
        ActivationPolicy.windowOpened()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        ActivationPolicy.windowClosed()
    }

    private func buildView() -> StatsView {
        let triggers = (try? triggerStore.load().triggers) ?? []
        let rows = triggers.compactMap { t -> StatsView.Row? in
            guard let entry = statsStore.entry(for: t.id),
                  entry.fireCount > 0 else { return nil }
            return StatsView.Row(id: t.id,
                                 trigger: t.trigger,
                                 title: t.title,
                                 fireCount: entry.fireCount,
                                 lastFiredAt: entry.lastFiredAt)
        }
        return StatsView(
            rows: rows,
            totalFires: statsStore.totalFires,
            onReset: { [weak self] in self?.confirmReset() },
            onRefresh: { [weak self] in self?.refresh() }
        )
    }

    private func refresh() {
        host.rootView = buildView()
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Reset all statistics?"
        alert.informativeText = "Fire counts and last-fired timestamps will be cleared. Your triggers themselves are untouched."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            statsStore.reset()
            refresh()
        }
    }
}
