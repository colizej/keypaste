import XCTest
import Carbon.HIToolbox
@testable import KeyPaste

// Only the pure classify(_:) function is exercised here — the full
// CGEvent tap requires accessibility permission and a runloop, which
// XCTest can't grant. Smoke-test verifies the live tap path.

final class EventTapTests: XCTestCase {
    private func input(_ keycode: Int,
                       _ unicode: String = "",
                       flags: CGEventFlags = []) -> EventTap.KeyInput {
        EventTap.KeyInput(keycode: keycode, flags: flags, unicodeString: unicode)
    }

    func testBackspaceKeycode() {
        XCTAssertEqual(EventTap.classify(input(kVK_Delete)), .backspace)
    }

    func testEscapeKeycode() {
        XCTAssertEqual(EventTap.classify(input(kVK_Escape)), .escape)
    }

    func testSpaceIsBoundary() {
        XCTAssertEqual(EventTap.classify(input(kVK_Space, " ")),
                       .boundary(" "))
    }

    func testTabIsBoundary() {
        XCTAssertEqual(EventTap.classify(input(kVK_Tab, "\t")),
                       .boundary("\t"))
    }

    func testReturnIsBoundary() {
        let kind = EventTap.classify(input(kVK_Return, "\r"))
        if case let .boundary(c) = kind {
            XCTAssertTrue(c.isNewline, "got \(c)")
        } else {
            XCTFail("expected boundary, got \(kind)")
        }
    }

    func testLetterIsPrintable() {
        XCTAssertEqual(EventTap.classify(input(kVK_ANSI_A, "a")),
                       .printable("a"))
    }

    func testDigitIsPrintable() {
        XCTAssertEqual(EventTap.classify(input(kVK_ANSI_1, "1")),
                       .printable("1"))
    }

    func testPunctuationIsPrintable() {
        XCTAssertEqual(EventTap.classify(input(kVK_ANSI_Period, ".")),
                       .printable("."))
    }

    func testCommandFlagYieldsModifierCombo() {
        let kind = EventTap.classify(input(kVK_ANSI_V, "v",
                                            flags: .maskCommand))
        XCTAssertEqual(kind, .modifierCombo)
    }

    func testControlFlagYieldsModifierCombo() {
        let kind = EventTap.classify(input(kVK_ANSI_C, "c",
                                            flags: .maskControl))
        XCTAssertEqual(kind, .modifierCombo)
    }

    func testOptionFlagYieldsModifierCombo() {
        let kind = EventTap.classify(input(kVK_ANSI_A, "å",
                                            flags: .maskAlternate))
        XCTAssertEqual(kind, .modifierCombo)
    }

    func testShiftAloneStillTreatsKeyNormally() {
        // Shift = uppercase letter; shouldn't be classed as modifierCombo.
        XCTAssertEqual(EventTap.classify(input(kVK_ANSI_A, "A",
                                                flags: .maskShift)),
                       .printable("A"))
    }

    func testEmptyUnicodeYieldsOther() {
        // Arrow keys etc. — keycode unknown to us, no character produced.
        XCTAssertEqual(EventTap.classify(input(kVK_LeftArrow, "")), .other)
    }

    func testModifierComboWinsOverBackspace() {
        // Cmd+Backspace is "delete word/line" in many apps — treat as combo.
        XCTAssertEqual(EventTap.classify(input(kVK_Delete, "",
                                                flags: .maskCommand)),
                       .modifierCombo)
    }
}
