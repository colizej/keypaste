import XCTest
@testable import KeyPaste

final class EngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let epoch = Date(timeIntervalSince1970: 0)

    private final class RecordingPaste: PasteStrategy {
        var calls: [(erase: Int, insert: String, cursor: Int?, postKeys: [Template.PostKey])] = []
        func expand(eraseCount: Int, insert text: String,
                    cursorOffset: Int?, postKeys: [Template.PostKey]) {
            calls.append((eraseCount, text, cursorOffset, postKeys))
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

    func testInstantFireWhenLastPrintableCompletesTrigger() {
        let (e, m) = makeEngine([trigger("email", "u@example.com")])
        for c in "email" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1)
        XCTAssertEqual(m.calls[0].erase, 5, "exact trigger length, no boundary")
        XCTAssertEqual(m.calls[0].insert, "u@example.com")
    }

    func testBufferResetAfterFire() {
        let (e, _) = makeEngine([trigger("hi", "hello")])
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(e.bufferContents, "",
                       "post-fire buffer is empty so the next word starts clean")
    }

    func testNoFireMidWord() {
        // 'email' is a suffix once typed, but only AT char 5. Typing one
        // more char ('i') pushes it past — but the cooldown:0 matcher
        // would still see "emaili" which doesn't end in any trigger. Good.
        let (e, m) = makeEngine([trigger("email", "X")])
        for c in "email" { e.handle(.printable(c), now: t0) }
        for c in "ing"   { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1, "fires once on 'email', not again")
    }

    func testBoundaryAfterTriggerDoesNotDoubleFire() {
        let (e, m) = makeEngine([trigger("hi", "hello")])
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1)
        e.handle(.boundary(" "), now: t0)
        XCTAssertEqual(m.calls.count, 1, "boundary alone never fires")
    }

    func testBoundaryWithoutPriorMatchJustResets() {
        let (e, m) = makeEngine([trigger("xyz", "X")])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        e.handle(.boundary(" "), now: t0)
        XCTAssertTrue(m.calls.isEmpty)
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
        XCTAssertEqual(m.calls.first?.insert, "Best, alice")
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
        XCTAssertEqual(m.calls.count, 1)
        // Buffer was reset post-fire; typing the trigger again fires again.
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 2)
    }

    func testSetTriggersUpdatesMatching() {
        let (e, m) = makeEngine([trigger("old", "OLD")])
        for c in "old" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1)

        e.setTriggers([trigger("new", "NEW")])
        for c in "old" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1, "old trigger no longer matches")

        for c in "new" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 2)
        XCTAssertEqual(m.calls.last?.insert, "NEW")
    }

    func testPausedEngineIgnoresPrintableEvents() {
        let (e, m) = makeEngine([trigger("hi", "hello")])
        e.setPaused(true)
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertTrue(m.calls.isEmpty)
        XCTAssertEqual(e.bufferContents, "", "no buffer accumulation while paused")
    }

    func testResumeAfterPauseStartsFresh() {
        let (e, m) = makeEngine([trigger("hi", "hello")])
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1)

        e.setPaused(true)
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 1, "no fire while paused")

        e.setPaused(false)
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.count, 2, "fires again after resume")
    }

    func testSetPausedTrueClearsBuffer() {
        let (e, _) = makeEngine([])
        for c in "abc" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(e.bufferContents, "abc")
        e.setPaused(true)
        XCTAssertEqual(e.bufferContents, "")
    }

    func testIsPausedReflectsState() {
        let (e, _) = makeEngine([])
        XCTAssertFalse(e.isPaused)
        e.setPaused(true)
        XCTAssertTrue(e.isPaused)
        e.setPaused(false)
        XCTAssertFalse(e.isPaused)
    }

    func testCursorTokenFlowsThroughToPaste() {
        let (e, m) = makeEngine([trigger(";l", "Dear {{cursor}},\nBest")])
        for c in ";l" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.first?.insert, "Dear ,\nBest")
        XCTAssertEqual(m.calls.first?.cursor, 5,
                       "caret should land between 'Dear ' and ','")
    }

    func testNoCursorTokenLeavesOffsetNil() {
        let (e, m) = makeEngine([trigger("hi", "hello")])
        for c in "hi" { e.handle(.printable(c), now: t0) }
        XCTAssertNil(m.calls.first?.cursor)
        XCTAssertEqual(m.calls.first?.postKeys, [])
    }

    func testEnterTokenFlowsThroughToPaste() {
        let (e, m) = makeEngine([trigger(";pw", "secret{{enter}}")])
        for c in ";pw" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.first?.insert, "secret",
                       "{{enter}} consumed, not in text")
        XCTAssertEqual(m.calls.first?.postKeys, [.enter])
    }

    func testTabTokenFlowsThroughToPaste() {
        let (e, m) = makeEngine([trigger(";login", "user{{tab}}pass{{enter}}")])
        for c in ";login" { e.handle(.printable(c), now: t0) }
        XCTAssertEqual(m.calls.first?.insert, "userpass")
        XCTAssertEqual(m.calls.first?.postKeys, [.tab, .enter])
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
        XCTAssertEqual(m.calls.first?.insert, "[{{date}}]")
    }
}
