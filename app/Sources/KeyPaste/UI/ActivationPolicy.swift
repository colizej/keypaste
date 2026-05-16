import AppKit
import Foundation

// Reference-counted activation-policy keeper.
//
// NSApp starts in .accessory (menu-bar only). When a window opens we
// flip to .regular so it can be foregrounded with a Dock icon; when
// the LAST window closes we flip back to .accessory. Each window
// controller calls windowOpened()/windowClosed() in show() / windowWillClose
// — naïvely flipping in each controller's delegate would hide the Dock
// icon while another window is still open.

@MainActor
enum ActivationPolicy {
    private static var openCount = 0

    static func windowOpened() {
        openCount += 1
        if openCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func windowClosed() {
        openCount = max(0, openCount - 1)
        if openCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
