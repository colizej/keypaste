import XCTest
@testable import KeyPaste

final class TemplateTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)
    private let weekday2 = Date(timeIntervalSince1970: 1_700_000_000)
    // 2023-11-14T22:13:20Z = Tuesday

    private func render(_ s: String,
                        clipboard: String = "",
                        username: String = "",
                        date: Date? = nil) -> Template.Rendered {
        let ctx = Template.Context(clipboard: clipboard,
                                   username: username,
                                   date: date ?? epoch)
        return Template.render(s, context: ctx)
    }

    // MARK: existing single-pass + injection guards

    func testReplacesClipboardPlaceholder() {
        XCTAssertEqual(render("Got: {{clipboard}}", clipboard: "hello").text,
                       "Got: hello")
    }

    func testReplacesUsernamePlaceholder() {
        XCTAssertEqual(render("Hi, {{name}}!", username: "alice").text,
                       "Hi, alice!")
    }

    func testReplacesDatePlaceholder() {
        XCTAssertEqual(render("Today is {{date}}").text, "Today is 1970-01-01")
    }

    func testClipboardCannotInjectAnotherPlaceholder() {
        let r = render("[{{clipboard}}]", clipboard: "{{date}}")
        XCTAssertEqual(r.text, "[{{date}}]")
    }

    func testUnknownTokenIsLeftLiteral() {
        XCTAssertEqual(render("hi {{nope}} bye").text, "hi {{nope}} bye")
    }

    func testWhitespaceInsidePlaceholderIsTolerated() {
        XCTAssertEqual(render("{{  name  }}", username: "bob").text, "bob")
    }

    func testUnterminatedPlaceholderIsLeftLiteral() {
        XCTAssertEqual(render("a {{clipboard but no close").text,
                       "a {{clipboard but no close")
    }

    func testMultiplePlaceholdersInOneString() {
        let r = render("{{name}}/{{clipboard}}/{{date}}",
                       clipboard: "C", username: "U")
        XCTAssertEqual(r.text, "U/C/1970-01-01")
    }

    func testAdjacentPlaceholdersWithNoSeparator() {
        let r = render("{{name}}{{clipboard}}", clipboard: "C", username: "U")
        XCTAssertEqual(r.text, "UC")
    }

    func testEmptyStringRendersEmpty() {
        XCTAssertEqual(render("").text, "")
    }

    func testNoPlaceholdersIsIdentity() {
        XCTAssertEqual(render("just plain text").text, "just plain text")
    }

    // MARK: new tokens

    func testTimeToken() {
        // epoch is 1970-01-01 00:00:00 UTC; current device TZ formats it
        // — we just assert the shape (HH:mm) and length.
        let r = render("at {{time}}")
        XCTAssertTrue(r.text.hasPrefix("at "))
        let suffix = String(r.text.dropFirst(3))
        XCTAssertEqual(suffix.count, 5, "HH:mm")
        XCTAssertEqual(suffix.firstIndex(of: ":"), suffix.index(suffix.startIndex, offsetBy: 2))
    }

    func testDatetimeToken() {
        let r = render("{{datetime}}")
        XCTAssertEqual(r.text.count, "yyyy-MM-dd HH:mm".count)
    }

    func testWeekdayToken() {
        // 2023-11-14 was a Tuesday in UTC.
        let r = render("{{weekday}}", date: weekday2)
        XCTAssertTrue(["Monday", "Tuesday", "Wednesday"].contains(r.text),
                      "weekday shape sanity check; got: \(r.text)")
    }

    func testUuidTokenLengthAndDashes() {
        let r = render("{{uuid}}")
        XCTAssertEqual(r.text.count, 36, "standard UUID string length")
        XCTAssertEqual(r.text.filter { $0 == "-" }.count, 4)
    }

    func testUuidTokenIsFreshEachCall() {
        XCTAssertNotEqual(render("{{uuid}}").text, render("{{uuid}}").text)
    }

    // MARK: date arg variants

    func testDateLongFormat() {
        let r = render("{{date:long}}",
                       date: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(r.text.contains("November"), "got: \(r.text)")
        XCTAssertTrue(r.text.contains("2023"))
    }

    func testDateIsoFormat() {
        let r = render("{{date:iso}}", date: epoch)
        XCTAssertEqual(r.text, "1970-01-01T00:00:00Z")
    }

    func testDateRelativeOffsetPlusOneDay() {
        let r = render("{{date:+1d}}", date: epoch)
        XCTAssertEqual(r.text, "1970-01-02")
    }

    func testDateRelativeOffsetMinusOneWeek() {
        // 1970-01-08 minus a week = 1970-01-01
        let start = Date(timeIntervalSince1970: 7 * 86_400)
        let r = render("{{date:-1w}}", date: start)
        XCTAssertEqual(r.text, "1970-01-01")
    }

    func testDateRelativeOffsetPlusOneMonth() {
        let r = render("{{date:+1m}}", date: epoch)
        XCTAssertEqual(r.text, "1970-02-01")
    }

    func testDateRelativeOffsetPlusOneYear() {
        let r = render("{{date:+1y}}", date: epoch)
        XCTAssertEqual(r.text, "1971-01-01")
    }

    func testDateCustomFormatPassedThrough() {
        let r = render("{{date:yyyy}}", date: epoch)
        XCTAssertEqual(r.text, "1970")
    }

    // MARK: {{cursor}}

    func testCursorTokenRemovedFromOutput() {
        let r = render("Hi {{cursor}}!")
        XCTAssertEqual(r.text, "Hi !")
    }

    func testCursorTokenOffsetIsAtItsPosition() {
        let r = render("Hi {{cursor}}!")
        XCTAssertEqual(r.cursorOffset, 3, "right after 'Hi '")
    }

    func testCursorOffsetIsNilWhenNoToken() {
        let r = render("Hi there")
        XCTAssertNil(r.cursorOffset)
    }

    func testFirstCursorTokenWinsOverDuplicates() {
        let r = render("a{{cursor}}b{{cursor}}c")
        XCTAssertEqual(r.text, "abc")
        XCTAssertEqual(r.cursorOffset, 1, "first one's position wins")
    }

    func testCursorMixedWithOtherTokens() {
        let r = render("Dear {{cursor}},\n\nBest,\n{{name}}",
                       username: "alice")
        XCTAssertEqual(r.text, "Dear ,\n\nBest,\nalice")
        XCTAssertEqual(r.cursorOffset, 5)
    }

    // MARK: empty-line preservation (regression check)

    func testConsecutiveNewlinesPassedThroughVerbatim() {
        let r = render("Line 1\n\n\nLine 2")
        XCTAssertEqual(r.text, "Line 1\n\n\nLine 2")
    }

    func testEmptyLineBetweenTokens() {
        let r = render("{{name}}\n\n{{date}}", username: "alice")
        XCTAssertEqual(r.text, "alice\n\n1970-01-01")
    }

    func testTrailingAndLeadingNewlinesKept() {
        let r = render("\n\n{{name}}\n\n", username: "u")
        XCTAssertEqual(r.text, "\n\nu\n\n")
    }
}
