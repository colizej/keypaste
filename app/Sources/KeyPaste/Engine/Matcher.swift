import Foundation

// Linear suffix matcher. For each `match(in:)` call, scans the trigger
// list and returns the longest trigger that is a suffix of the buffer.
// Triggers are sorted longest-first at setTriggers() so the first hit is
// already the longest match (e.g. "email" wins over "em").
//
// Cooldown is a small guard against re-firing right after an expansion:
// even though Engine resets the buffer post-paste, simulated keystrokes
// can briefly leak back through the event tap on some keyboards.
//
// TODO: replace with Aho-Corasick when the user's trigger list grows past
// ~200 entries. At that scale the linear scan still completes in well
// under a millisecond, but Aho-Corasick removes the dependency on list
// size entirely.

final class Matcher {
    static let defaultCooldown: TimeInterval = 0.2

    private(set) var triggers: [Trigger] = []
    private(set) var lastFireAt: Date?
    let cooldown: TimeInterval

    init(cooldown: TimeInterval = Matcher.defaultCooldown) {
        self.cooldown = cooldown
    }

    func setTriggers(_ triggers: [Trigger]) {
        self.triggers = triggers
            .filter { !$0.trigger.isEmpty }
            .sorted { $0.trigger.count > $1.trigger.count }
    }

    func match(in buffer: String,
               currentScope: String? = nil,
               now: Date = Date()) -> Trigger? {
        if let last = lastFireAt, now.timeIntervalSince(last) < cooldown {
            return nil
        }
        for trigger in triggers where buffer.hasSuffix(trigger.trigger) {
            // Trigger.scope == nil means "any app". Otherwise the trigger
            // only fires when the frontmost app's bundle ID matches.
            if let scope = trigger.scope, scope != currentScope {
                continue
            }
            lastFireAt = now
            return trigger
        }
        return nil
    }

    func resetCooldown() {
        lastFireAt = nil
    }
}
