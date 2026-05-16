import Foundation

// Orchestrates Buffer + Matcher + Template + a paste sink.
//
// The paste sink is injected through the PasteStrategy protocol so this
// module stays AppKit-free and trivially testable. The System layer
// supplies the concrete NSPasteboard+CGEvent implementation.
//
// Firing model: instant-fire on suffix match. The moment the typed
// buffer ends with a trigger string, expansion happens — no boundary
// key required. Boundaries still reset the buffer (so a new word
// starts cleanly) but do not themselves trigger anything. Tradeoff:
// trigger names that are prefixes of common words will fire mid-word;
// users design trigger names to avoid that.
// Engine itself classifies events into KeyKind; the EventTap layer
// converts CGEvent → KeyKind so Engine never touches Carbon types.
//
// Threading: Engine assumes serial access. EventTap dispatches each
// callback to a single serial queue, so no locks are needed here.

protocol PasteStrategy: AnyObject {
    // Erase `eraseCount` chars from the focused text field, then insert
    // `text`. Implementations are free to use any IME-safe mechanism;
    // the System layer uses backspace + NSPasteboard + Cmd+V.
    func expand(eraseCount: Int, insert text: String)
}

final class Engine {
    enum KeyKind: Equatable {
        case printable(Character)
        case backspace
        case boundary(Character)   // whitespace / newline / tab
        case escape
        case modifierCombo         // any Cmd/Ctrl/Opt combo
        case other                 // arrows, fn keys, etc.
    }

    private var buffer: Buffer
    private let matcher: Matcher
    private let paste: PasteStrategy
    private var renderContext: () -> Template.Context

    func setTriggers(_ triggers: [Trigger]) {
        matcher.setTriggers(triggers)
    }

    init(buffer: Buffer = Buffer(),
         matcher: Matcher = Matcher(),
         paste: PasteStrategy,
         renderContext: @escaping () -> Template.Context = Engine.defaultContext) {
        self.buffer = buffer
        self.matcher = matcher
        self.paste = paste
        self.renderContext = renderContext
    }

    static func defaultContext() -> Template.Context {
        Template.Context(clipboard: "", username: NSUserName(), date: Date())
    }

    var bufferContents: String { buffer.contents }

    // Called by EventTap for every key event. The return value indicates
    // whether the event should pass through to the focused app — always
    // true: the typed key reaches the app, then erase+insert is posted
    // into the event stream after.
    @discardableResult
    func handle(_ kind: KeyKind, now: Date = Date()) -> Bool {
        switch kind {
        case .printable(let c):
            buffer.append(c)
            if let trigger = matcher.match(in: buffer.contents, now: now) {
                let rendered = Template.render(trigger.content,
                                               context: renderContext())
                paste.expand(eraseCount: trigger.trigger.count,
                             insert: rendered)
                buffer.reset()
            }
            return true

        case .boundary:
            buffer.reset()
            return true

        case .backspace:
            buffer.backspace()
            return true

        case .escape, .modifierCombo, .other:
            buffer.reset()
            return true
        }
    }

    // Called by System on NSWorkspace.didActivateApplicationNotification
    // and when IsSecureEventInputEnabled() flips on.
    func reset() {
        buffer.reset()
        matcher.resetCooldown()
    }
}
