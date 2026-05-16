import XCTest
@testable import KeyPaste

final class TemplateTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    func testReplacesClipboardPlaceholder() {
        let ctx = Template.Context(clipboard: "hello", username: "u", date: epoch)
        XCTAssertEqual(Template.render("Got: {{clipboard}}", context: ctx),
                       "Got: hello")
    }

    func testReplacesUsernamePlaceholder() {
        let ctx = Template.Context(clipboard: "", username: "alice", date: epoch)
        XCTAssertEqual(Template.render("Hi, {{name}}!", context: ctx),
                       "Hi, alice!")
    }

    func testReplacesDatePlaceholder() {
        let ctx = Template.Context(clipboard: "", username: "", date: epoch)
        XCTAssertEqual(Template.render("Today is {{date}}", context: ctx),
                       "Today is 1970-01-01")
    }

    // Clipboard content containing a literal {{date}} must NOT be re-expanded.
    // The sequential-replace implementation had this bug; single-pass fixes it.
    func testClipboardCannotInjectAnotherPlaceholder() {
        let ctx = Template.Context(clipboard: "{{date}}", username: "u", date: epoch)
        XCTAssertEqual(Template.render("[{{clipboard}}]", context: ctx),
                       "[{{date}}]")
    }

    func testUnknownTokenIsLeftLiteral() {
        let ctx = Template.Context(clipboard: "", username: "", date: epoch)
        XCTAssertEqual(Template.render("hi {{nope}} bye", context: ctx),
                       "hi {{nope}} bye")
    }

    func testWhitespaceInsidePlaceholderIsTolerated() {
        let ctx = Template.Context(clipboard: "", username: "bob", date: epoch)
        XCTAssertEqual(Template.render("{{  name  }}", context: ctx), "bob")
    }

    func testUnterminatedPlaceholderIsLeftLiteral() {
        let ctx = Template.Context(clipboard: "x", username: "", date: epoch)
        XCTAssertEqual(Template.render("a {{clipboard but no close",
                                       context: ctx),
                       "a {{clipboard but no close")
    }

    func testMultiplePlaceholdersInOneString() {
        let ctx = Template.Context(clipboard: "C", username: "U", date: epoch)
        XCTAssertEqual(Template.render("{{name}}/{{clipboard}}/{{date}}",
                                       context: ctx),
                       "U/C/1970-01-01")
    }

    func testAdjacentPlaceholdersWithNoSeparator() {
        let ctx = Template.Context(clipboard: "C", username: "U", date: epoch)
        XCTAssertEqual(Template.render("{{name}}{{clipboard}}", context: ctx),
                       "UC")
    }

    func testEmptyStringRendersEmpty() {
        let ctx = Template.Context(clipboard: "x", username: "y", date: epoch)
        XCTAssertEqual(Template.render("", context: ctx), "")
    }

    func testNoPlaceholdersIsIdentity() {
        let ctx = Template.Context(clipboard: "x", username: "y", date: epoch)
        XCTAssertEqual(Template.render("just plain text", context: ctx),
                       "just plain text")
    }
}
