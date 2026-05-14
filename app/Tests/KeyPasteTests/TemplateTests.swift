import XCTest
@testable import KeyPaste

final class TemplateTests: XCTestCase {
    func testReplacesClipboardPlaceholder() {
        let ctx = Template.Context(clipboard: "hello", username: "u",
                                   date: Date(timeIntervalSince1970: 0))
        let out = Template.render("Got: {{clipboard}}", context: ctx)
        XCTAssertEqual(out, "Got: hello")
    }

    func testReplacesUsernamePlaceholder() {
        let ctx = Template.Context(clipboard: "", username: "alice",
                                   date: Date(timeIntervalSince1970: 0))
        let out = Template.render("Hi, {{name}}!", context: ctx)
        XCTAssertEqual(out, "Hi, alice!")
    }

    func testReplacesDatePlaceholder() {
        let ctx = Template.Context(clipboard: "", username: "",
                                   date: Date(timeIntervalSince1970: 0))
        let out = Template.render("Today is {{date}}", context: ctx)
        XCTAssertEqual(out, "Today is 1970-01-01")
    }
}
