import Foundation

// Single-pass template renderer. Walks the source once, substitutes
// `{{token}}` and `{{token:arg}}` placeholders, and returns the final
// text along with an optional cursor offset (the position where the
// `{{cursor}}` token was, if present).
//
// Replacement values are emitted verbatim and NOT rescanned — so a
// clipboard containing the literal "{{date}}" stays literal in the
// output instead of being expanded.
//
// Supported tokens:
//   {{clipboard}}
//   {{name}}
//   {{date}}                    yyyy-MM-dd
//   {{date:long}}               May 16, 2026
//   {{date:iso}}                2026-05-16T19:30:00Z
//   {{date:+1d}} / {{date:-2w}} relative offset, days|weeks|months|years
//   {{date:yyyy-MM}}            custom DateFormatter pattern
//   {{time}}                    HH:mm
//   {{datetime}}                yyyy-MM-dd HH:mm
//   {{weekday}}                 Friday
//   {{uuid}}                    a fresh UUID v4
//   {{cursor}}                  removed from output; cursorOffset set
//                               to its grapheme position so PasteStrategy
//                               can park the caret there
//   {{enter}}                   removed from output; appended to
//                               postKeys so PasteStrategy presses Return
//                               AFTER the paste lands. Use case: form
//                               submission (e.g. password + Enter).
//   {{tab}}                     same as {{enter}} but the Tab key —
//                               handy for moving to the next form field.
// Unknown tokens are emitted unchanged so typos are visible.

enum Template {
    struct Context {
        let clipboard: String
        let username: String
        let date: Date
    }

    enum PostKey: Equatable {
        case enter
        case tab
    }

    struct Rendered: Equatable {
        let text: String
        /// Grapheme-cluster index where the caret should land after the
        /// paste completes. `nil` means "leave the caret wherever the
        /// host app puts it" (which is end-of-paste by default).
        let cursorOffset: Int?
        /// Key events to post AFTER the paste (and cursor positioning).
        /// Sourced from {{enter}} / {{tab}} tokens in the order they
        /// appear in the content.
        let postKeys: [PostKey]
    }

    static func render(_ source: String, context: Context) -> Rendered {
        let chars = Array(source)
        var out = ""
        out.reserveCapacity(chars.count)
        var cursorOffset: Int? = nil
        var postKeys: [PostKey] = []
        var i = 0
        while i < chars.count {
            if i + 1 < chars.count, chars[i] == "{", chars[i + 1] == "{",
               let closeAt = findClose(chars, from: i + 2) {
                let raw = String(chars[(i + 2)..<closeAt])
                    .trimmingCharacters(in: .whitespaces)
                let split = raw.split(separator: ":", maxSplits: 1)
                let name = split.first.map(String.init) ?? ""
                let arg  = split.count > 1 ? String(split[1]) : nil

                // {{cursor}} is removed from the output; first occurrence
                // wins so a stray second token doesn't silently override.
                if name == "cursor" {
                    if cursorOffset == nil {
                        cursorOffset = out.count
                    }
                    i = closeAt + 2
                    continue
                }
                if name == "enter" {
                    postKeys.append(.enter)
                    i = closeAt + 2
                    continue
                }
                if name == "tab" {
                    postKeys.append(.tab)
                    i = closeAt + 2
                    continue
                }

                if let value = substitute(name: name, arg: arg, context: context) {
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
        return Rendered(text: out, cursorOffset: cursorOffset, postKeys: postKeys)
    }

    private static func findClose(_ chars: [Character], from start: Int) -> Int? {
        var j = start
        while j + 1 < chars.count {
            if chars[j] == "}", chars[j + 1] == "}" { return j }
            j += 1
        }
        return nil
    }

    private static func substitute(name: String,
                                   arg: String?,
                                   context: Context) -> String? {
        switch name {
        case "clipboard": return context.clipboard
        case "name":      return context.username
        case "date":      return renderDate(arg: arg, base: context.date)
        case "time":      return timeFormatter.string(from: context.date)
        case "datetime":  return datetimeFormatter.string(from: context.date)
        case "weekday":   return weekdayFormatter.string(from: context.date)
        case "uuid":      return UUID().uuidString
        default:          return nil
        }
    }

    private static func renderDate(arg: String?, base: Date) -> String {
        guard let arg = arg, !arg.isEmpty else {
            return dateFormatter.string(from: base)
        }
        if let shifted = applyOffset(arg, to: base) {
            return dateFormatter.string(from: shifted)
        }
        switch arg {
        case "long":
            let df = DateFormatter()
            df.dateStyle = .long
            df.timeStyle = .none
            df.locale = Locale(identifier: "en_US_POSIX")
            return df.string(from: base)
        case "iso":
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: base)
        default:
            let df = DateFormatter()
            df.dateFormat = arg
            df.locale = Locale(identifier: "en_US_POSIX")
            return df.string(from: base)
        }
    }

    /// Parses `+1d`, `-2w`, `+3m`, `-1y` (days/weeks/months/years).
    /// Returns nil if `arg` doesn't match — caller treats it as a format string.
    private static func applyOffset(_ arg: String, to date: Date) -> Date? {
        guard let first = arg.first, first == "+" || first == "-" else {
            return nil
        }
        let sign = first == "+" ? 1 : -1
        let rest = arg.dropFirst()
        guard let unit = rest.last, "dwmy".contains(unit),
              let amount = Int(rest.dropLast()) else {
            return nil
        }
        var components = DateComponents()
        switch unit {
        case "d": components.day   = sign * amount
        case "w": components.day   = sign * amount * 7
        case "m": components.month = sign * amount
        case "y": components.year  = sign * amount
        default:  return nil
        }
        return Calendar(identifier: .gregorian).date(byAdding: components, to: date)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let datetimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
