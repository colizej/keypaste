import AppKit
import Carbon.HIToolbox
import Foundation

// Concrete PasteStrategy used in production.
//
// Flow on expand(eraseCount:insert:):
//   1. Snapshot every NSPasteboardItem on the general pasteboard so rich
//      content (RTF, images, files) survives the paste — restoring just
//      the string type would silently corrupt non-text clipboards.
//   2. Clear the pasteboard and write `insert` as a plain string.
//   3. Post `eraseCount` Backspace key events through CGEvent. These
//      replay through the system event stream and reach the focused app
//      AFTER the boundary char the user just typed, so the user-visible
//      sequence is "type trigger + space → text gets replaced".
//   4. Post Cmd+V. The focused app reads our string from the pasteboard
//      and inserts it.
//   5. After `restoreDelay` (default 250ms — long enough for the paste
//      to complete on slower apps, short enough that the user rarely
//      notices), restore the snapshot.
//
// Every injected event is tagged with a magic eventSourceUserData so
// EventTap can ignore the echo and not feed our own backspaces back
// into the engine's buffer.
//
// All work hops to the main queue. NSPasteboard and CGEvent.post are
// technically thread-friendly, but main-thread keeps the timing
// predictable and avoids occasional clipboard-restore races we've seen
// in the legacy code.

final class SystemPasteStrategy: PasteStrategy {
    static let injectedSourceUserData: Int64 = 0x4B70_5374  // ASCII 'KpSt'

    // Closure so SettingsStore can drive the value live without rebuilding
    // the strategy. Defaults to 250ms for callers who don't care.
    private let restoreDelayProvider: () -> TimeInterval
    private let tapLocation: CGEventTapLocation

    init(restoreDelay: @escaping () -> TimeInterval = { 0.25 },
         tapLocation: CGEventTapLocation = .cghidEventTap) {
        self.restoreDelayProvider = restoreDelay
        self.tapLocation = tapLocation
    }

    func expand(eraseCount: Int, insert text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.performExpand(eraseCount: eraseCount, insert: text)
        }
    }

    private func performExpand(eraseCount: Int, insert text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = Self.snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)

        for _ in 0..<eraseCount {
            postKey(keycode: CGKeyCode(kVK_Delete), flags: [], source: source)
        }
        postKey(keycode: CGKeyCode(kVK_ANSI_V),
                flags: .maskCommand, source: source)

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelayProvider()) {
            Self.restore(snapshot, into: pasteboard)
        }
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private static func restore(_ snapshot: [NSPasteboardItem],
                                into pasteboard: NSPasteboard) {
        guard !snapshot.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(snapshot)
    }

    private func postKey(keycode: CGKeyCode,
                         flags: CGEventFlags,
                         source: CGEventSource?) {
        guard let down = CGEvent(keyboardEventSource: source,
                                 virtualKey: keycode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source,
                               virtualKey: keycode, keyDown: false) else {
            Logger.warning("CGEvent allocation failed for keycode \(keycode)")
            return
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData,
                                  value: Self.injectedSourceUserData)
        up.setIntegerValueField(.eventSourceUserData,
                                value: Self.injectedSourceUserData)
        down.post(tap: tapLocation)
        up.post(tap: tapLocation)
    }
}
