import Foundation

// Single-pass template renderer. Walks the source once and substitutes
// `{{token}}` placeholders. Replacement values are emitted verbatim and
// are NOT rescanned — so a clipboard containing the literal string
// "{{date}}" stays literal in the output instead of being expanded.
//
// Supported tokens: clipboard, name, date.
// Unknown tokens are emitted unchanged so users notice the typo.

enum Template {
    struct Context {
        let clipboard: String
        let username: String
        let date: Date
    }

    static func render(_ source: String, context: Context) -> String {
        let chars = Array(source)
        var out = ""
        out.reserveCapacity(chars.count)
        var i = 0
        while i < chars.count {
            if i + 1 < chars.count, chars[i] == "{", chars[i + 1] == "{",
               let closeAt = findClose(chars, from: i + 2) {
                let token = String(chars[(i + 2)..<closeAt])
                    .trimmingCharacters(in: .whitespaces)
                if let value = substitute(token, context: context) {
                    out.append(value)
                } else {
                    out.append(contentsOf: chars[i...(closeAt + 1)])
                }
                i = closeAt + 2
                continue
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    private static func findClose(_ chars: [Character], from start: Int) -> Int? {
        var j = start
        while j + 1 < chars.count {
            if chars[j] == "}", chars[j + 1] == "}" { return j }
            j += 1
        }
        return nil
    }

    private static func substitute(_ token: String, context: Context) -> String? {
        switch token {
        case "clipboard": return context.clipboard
        case "name":      return context.username
        case "date":      return dateFormatter.string(from: context.date)
        default:          return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
