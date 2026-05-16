import Foundation

// Sliding character buffer used by the matcher. Append printable
// characters as they're typed, pop on backspace, reset on any non-typing
// event. Boundary classification (whitespace, escape, modifier combos,
// app switch, secure-input-on) is the Engine's responsibility — keeping
// Buffer pure data makes it trivially testable.
//
// `maxLength` caps memory growth: when exceeded, the oldest characters
// are dropped (sliding window). 256 chars is well beyond any realistic
// trigger and small enough to keep matcher scans fast.

struct Buffer {
    static let defaultMaxLength = 256

    private(set) var contents: String = ""
    let maxLength: Int

    init(maxLength: Int = Buffer.defaultMaxLength) {
        self.maxLength = maxLength
    }

    var isEmpty: Bool { contents.isEmpty }

    mutating func append(_ char: Character) {
        contents.append(char)
        if contents.count > maxLength {
            let overflow = contents.count - maxLength
            contents.removeFirst(overflow)
        }
    }

    mutating func backspace() {
        if !contents.isEmpty { contents.removeLast() }
    }

    mutating func reset() {
        contents.removeAll(keepingCapacity: true)
    }
}
