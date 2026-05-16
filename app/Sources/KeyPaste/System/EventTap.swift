import AppKit
import Carbon.HIToolbox
import Foundation

// CGEvent tap that hands key events to Engine.
//
// Setup uses .cgSessionEventTap + .headInsertEventTap so we see events
// before any other tap and can take action synchronously. The callback
// returns the event unmodified; we never suppress — the boundary char
// reaches the focused app, our PasteStrategy then injects backspaces
// and Cmd+V after it.
//
// Three defenses against badness:
//   1. Echo filter — every PasteStrategy event carries
//      eventSourceUserData = SystemPasteStrategy.injectedSourceUserData;
//      we recognise that constant and skip the event entirely so our
//      own backspaces don't pop chars from Engine's buffer.
//   2. Secure input — when IsSecureEventInputEnabled() is true we hand
//      the event back untouched AND call engine.reset() so anything
//      typed into a password field can't leak into the matcher.
//   3. Tap auto-disable — the OS yanks the tap if the callback ever
//      takes more than ~1s, or sometimes seemingly at random.
//      .tapDisabledByTimeout / .tapDisabledByUserInput re-enable it.

final class EventTap {
    enum TapError: Error {
        case notAccessibilityTrusted
        case creationFailed
    }

    struct KeyInput: Equatable {
        let keycode: Int
        let flags: CGEventFlags
        let unicodeString: String
    }

    private let engine: Engine
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(engine: Engine) {
        self.engine = engine
    }

    func start() throws {
        guard PermissionsChecker.isAccessibilityTrusted() else {
            throw TapError.notAccessibilityTrusted
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let me = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.callback(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            throw TapError.creationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        Logger.info("Event tap started")
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        Logger.info("Event tap stopped")
    }

    private func callback(type: CGEventType,
                          event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = self.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                Logger.warning("Event tap re-enabled after \(type.rawValue)")
            }
            return Unmanaged.passUnretained(event)
        }

        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == SystemPasteStrategy.injectedSourceUserData {
            return Unmanaged.passUnretained(event)
        }

        if SecureInputDetector.isEnabled {
            engine.reset()
            return Unmanaged.passUnretained(event)
        }

        let kind = Self.classify(Self.input(from: event))
        engine.handle(kind)
        return Unmanaged.passUnretained(event)
    }

    static func input(from event: CGEvent) -> KeyInput {
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4,
                                       actualStringLength: &length,
                                       unicodeString: &buffer)
        let unicodeString = length > 0
            ? String(utf16CodeUnits: buffer, count: length)
            : ""
        return KeyInput(keycode: keycode,
                        flags: event.flags,
                        unicodeString: unicodeString)
    }

    static func classify(_ input: KeyInput) -> Engine.KeyKind {
        let modifierMask: CGEventFlags =
            [.maskCommand, .maskControl, .maskAlternate]
        if !input.flags.intersection(modifierMask).isEmpty {
            return .modifierCombo
        }

        if input.keycode == kVK_Delete { return .backspace }
        if input.keycode == kVK_Escape { return .escape }

        guard let char = input.unicodeString.first else { return .other }

        if char.isNewline || char == " " || char == "\t" {
            return .boundary(char)
        }
        if char.isLetter || char.isNumber
            || char.isPunctuation || char.isSymbol {
            return .printable(char)
        }
        return .other
    }
}
