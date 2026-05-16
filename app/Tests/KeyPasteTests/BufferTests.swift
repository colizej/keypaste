import XCTest
@testable import KeyPaste

final class BufferTests: XCTestCase {
    func testStartsEmpty() {
        let b = Buffer()
        XCTAssertTrue(b.isEmpty)
        XCTAssertEqual(b.contents, "")
    }

    func testAppendAccumulates() {
        var b = Buffer()
        for c in "abc" { b.append(c) }
        XCTAssertEqual(b.contents, "abc")
    }

    func testBackspacePopsLastChar() {
        var b = Buffer()
        for c in "abc" { b.append(c) }
        b.backspace()
        XCTAssertEqual(b.contents, "ab")
    }

    func testBackspaceOnEmptyIsNoop() {
        var b = Buffer()
        b.backspace()
        XCTAssertTrue(b.isEmpty)
    }

    func testResetClears() {
        var b = Buffer()
        for c in "hello" { b.append(c) }
        b.reset()
        XCTAssertTrue(b.isEmpty)
    }

    func testLengthCapDropsOldest() {
        var b = Buffer(maxLength: 4)
        for c in "abcdef" { b.append(c) }
        XCTAssertEqual(b.contents, "cdef")
    }

    func testLengthCapAtExactBoundary() {
        var b = Buffer(maxLength: 3)
        for c in "abc" { b.append(c) }
        XCTAssertEqual(b.contents, "abc")
        b.append("d")
        XCTAssertEqual(b.contents, "bcd")
    }

    func testHandlesUnicodeGraphemes() {
        var b = Buffer()
        b.append("é")
        b.append("中")
        b.append("a")
        XCTAssertEqual(b.contents, "é中a")
    }

    func testBackspaceAfterCapStillPopsLatest() {
        var b = Buffer(maxLength: 3)
        for c in "abcd" { b.append(c) }
        XCTAssertEqual(b.contents, "bcd")
        b.backspace()
        XCTAssertEqual(b.contents, "bc")
    }
}
