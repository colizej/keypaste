import XCTest
@testable import KeyPaste

final class EngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let epoch = Date(timeIntervalSince1970: 0)

    private final class RecordingPaste: PasteStrategy {
        var calls: [(erase: Int, insert: String)] = []
        func expand(eraseCount: Int, insert text: String) {
            calls.append((eraseCount, text))
        }
    }

    private func trigger(_ key: String, _ content: String = "X") -> Trigger {
        Trigger(id: ULID.generate(),
                trigger: key, content: content,
                title: "", scope: nil,
                createdAt: t0, updatedAt: t0)
    }

    private func makeEngine(
        _ triggers: [Trigger],
        context: Template.Context? = nil
    ) -> (Engine, RecordingPaste) {
        let mock = RecordingPaste()
        let ctx = context ?? Template.Context(clipboard: "",
                                              username: "u",
                                              date: epoch)
        let engine = Engine(matcher: Matcher(cooldown: 0),
                            paste: mock,
                            renderContext: { ctx })
        engine.setTriggers(triggers)
        return (engine, mock)
    }

    func testTypingTriggerThenBoundaryFiresExpansion() {
        let (e, m) = makeEngine([trigger("email", "u@example.com")])
        for c in "email" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 1)
        XCTAssertEqual(m.calls[0].erase, 6, "trigger length + boundary")
        XCTAssertEqual(m.calls[0].insert, "u@example.com ")
    }

    func testBoundaryWithoutMatchDoesNotFire() {
        let (e, m) = makeEngine([trigger("email")])
        for c in "hello" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertTrue(m.calls.isEmpty)
    }

    func testBoundaryAlwaysResetsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(e.bufferContents, "abc")
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(e.bufferContents, "")
    }

    func testBackspacePopsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        e.handle(.backspace, now: t0)
        XCTAssertEqual(e.bufferContents, "ab")
    }

    func testEscapeResetsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        e.handle(.escape, now: t0)
        XCTAssertEqual(e.bufferContents, "")
    }

    func testModifierComboResetsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        e.handle(.modifierCombo, now: t0)
        XCTAssertEqual(e.bufferContents, "")
    }

    func testTemplateRenderingThroughEngine() {
        let ctx = Template.Context(clipboard: "C", username: "alice", date: epoch)
        let (e, m) = makeEngine([trigger("sig", "Best, {{name}}")],
                                context: ctx)
        for c in "sig" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.first?.insert, "Best, alice ")
    }

    func testBoundaryCharIsPreservedInInsertion() {
        let (e, m) = makeEngine([trigger("ret", "value")])
        for c in "ret" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary("\n"), now: t0)
        XCTAssertEqual(m.calls.first?.insert, "value\n")
    }

    func testResetClearsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        e.reset()
        XCTAssertEqual(e.bufferContents, "")
    }

    func testTwoSequentialExpansionsBothFire() {
        let (e, m) = makeEngine([trigger("hi", "hello")])
        for c in "hi" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 1)

        for c in "hi" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 2)
    }

    func testSetTriggersUpdatesMatching() {
        let (e, m) = makeEngine([trigger("old", "OLD")])
        for c in "old" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 1)

        e.setTriggers([trigger("new", "NEW")])

        for c in "old" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 1, "old trigger no longer matches")

        for c in "new" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 2)
        XCTAssertEqual(m.calls.last?.insert, "NEW ")
    }

    func testClipboardCannotInjectTokenAtExpansion() {
        // Belt-and-suspenders: even if a clipboard string contains a
        // template token, Engine renders trigger.content through Template,
        // not the clipboard, so injection can't happen here.
        let ctx = Template.Context(clipboard: "{{date}}",
                                   username: "u", date: epoch)
        let (e, m) = makeEngine([trigger("c", "[{{clipboard}}]")],
                                context: ctx)
        e.handle(.printable("c"), now: t0)
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.first?.insert, "[{{date}}] ")
    }
}
