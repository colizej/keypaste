import ApplicationServices
import Foundation

// Thin wrapper around AXIsProcessTrustedWithOptions. Sprint 1 calls
// `isAccessibilityTrusted(prompt: true)` once at launch — macOS pops a
// system dialog and deep-links to System Settings → Privacy & Security
// → Accessibility. The user must enable the toggle for our binary AND
// restart the app; AX trust is loaded from TCC at process start and
// does not refresh live. App.swift detects the false-return and shows
// a follow-up NSAlert with restart instructions.

enum PermissionsChecker {
    static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
