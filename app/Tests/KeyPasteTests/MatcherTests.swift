import XCTest
@testable import KeyPaste

final class MatcherTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func trigger(_ key: String, _ content: String = "X") -> Trigger {
        Trigger(id: ULID.generate(),
                trigger: key, content: content,
                title: "", scope: nil,
                createdAt: t0, updatedAt: t0)
    }

    func testEmptyMatcherReturnsNil() {
        let m = Matcher()
        XCTAssertNil(m.match(in: "anything", now: t0))
    }

    func testSuffixMatchFires() {
        let m = Matcher()
        m.setTriggers([trigger("email")])
        XCTAssertEqual(m.match(in: "my email", now: t0)?.trigger, "email")
    }

    func testNonSuffixMatchDoesNotFire() {
        let m = Matcher()
        m.setTriggers([trigger("email")])
        XCTAssertNil(m.match(in: "email signature", now: t0))
    }

    func testEmptyBufferDoesNotFire() {
        let m = Matcher()
        m.setTriggers([trigger("x")])
        XCTAssertNil(m.match(in: "", now: t0))
    }

    func testEmptyTriggerIsIgnored() {
        let m = Matcher()
        m.setTriggers([trigger("")])
        XCTAssertNil(m.match(in: "anything", now: t0))
    }

    func testLongestSuffixWins() {
        let m = Matcher()
        m.setTriggers([trigger("em"), trigger("email")])
        XCTAssertEqual(m.match(in: "send email", now: t0)?.trigger, "email")
    }

    func testCooldownBlocksImmediateRefire() {
        let m = Matcher(cooldown: 0.2)
        m.setTriggers([trigger("hi")])
        XCTAssertNotNil(m.match(in: "hi", now: t0))
        XCTAssertNil(m.match(in: "hi", now: t0.addingTimeInterval(0.1)),
                     "within cooldown window, no fire")
    }

    func testCooldownReleasesAfterWindow() {
        let m = Matcher(cooldown: 0.2)
        m.setTriggers([trigger("hi")])
        XCTAssertNotNil(m.match(in: "hi", now: t0))
        XCTAssertNotNil(m.match(in: "hi", now: t0.addingTimeInterval(0.5)))
    }

    func testResetCooldownAllowsImmediateRefire() {
        let m = Matcher(cooldown: 1.0)
        m.setTriggers([trigger("hi")])
        XCTAssertNotNil(m.match(in: "hi", now: t0))
        m.resetCooldown()
        XCTAssertNotNil(m.match(in: "hi", now: t0))
    }

    func testSetTriggersReplacesPreviousList() {
        let m = Matcher()
        m.setTriggers([trigger("old")])
        XCTAssertNotNil(m.match(in: "old", now: t0))
        m.resetCooldown()
        m.setTriggers([trigger("new")])
        XCTAssertNil(m.match(in: "old", now: t0))
        XCTAssertNotNil(m.match(in: "new", now: t0))
    }

    func testMatcherReturnsFullTriggerObject() {
        let m = Matcher()
        let t = trigger("brb", "be right back")
        m.setTriggers([t])
        let result = m.match(in: "brb", now: t0)
        XCTAssertEqual(result?.id, t.id)
        XCTAssertEqual(result?.content, "be right back")
    }

    // MARK: per-app scope

    private func scopedTrigger(_ key: String, scope: String?) -> Trigger {
        Trigger(id: ULID.generate(),
                trigger: key, content: "X",
                title: "", scope: scope,
                createdAt: t0, updatedAt: t0)
    }

    func testNilScopeTriggerFiresInAnyApp() {
        let m = Matcher()
        m.setTriggers([scopedTrigger("hi", scope: nil)])
        XCTAssertNotNil(m.match(in: "hi", currentScope: "com.apple.Mail",
                                now: t0))
        m.resetCooldown()
        XCTAssertNotNil(m.match(in: "hi", currentScope: nil, now: t0))
    }

    func testScopedTriggerFiresOnlyInMatchingApp() {
        let m = Matcher()
        m.setTriggers([scopedTrigger("addr", scope: "com.apple.Mail")])
        XCTAssertNotNil(m.match(in: "addr",
                                currentScope: "com.apple.Mail",
                                now: t0))
        m.resetCooldown()
        XCTAssertNil(m.match(in: "addr",
                             currentScope: "com.apple.Safari",
                             now: t0))
        XCTAssertNil(m.match(in: "addr", currentScope: nil, now: t0))
    }

    func testTwoScopedTriggersWithSameKeyChooseByApp() {
        let m = Matcher()
        m.setTriggers([
            scopedTrigger("addr", scope: "com.apple.Mail"),
            scopedTrigger("addr", scope: "com.apple.MobileSMS"),
        ])
        let mail = m.match(in: "addr",
                           currentScope: "com.apple.Mail", now: t0)
        m.resetCooldown()
        let sms  = m.match(in: "addr",
                           currentScope: "com.apple.MobileSMS", now: t0)
        XCTAssertEqual(mail?.scope, "com.apple.Mail")
        XCTAssertEqual(sms?.scope, "com.apple.MobileSMS")
    }
}
