import Foundation
import Carbon.HIToolbox

// IsSecureEventInputEnabled() is set whenever a focused field has marked
// itself as secure (password fields, lock screen, sudo prompt in
// Terminal, 1Password's master prompt, etc). The event tap still fires
// while it's on, but processing keys then would risk leaking secrets
// into our buffer, so Engine drops everything while this returns true.

enum SecureInputDetector {
    static var isEnabled: Bool { IsSecureEventInputEnabled() }
}
