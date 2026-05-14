import Foundation

// Template rendering. Sprint 1 will replace this placeholder with a single-
// pass tokenizer so clipboard contents can't inject `{{date}}` etc.

enum Template {
    struct Context {
        let clipboard: String
        let username: String
        let date: Date
    }

    static func render(_ source: String, context: Context) -> String {
        // TODO(sprint-1): single-pass tokenizer instead of sequential replace.
        var out = source
        out = out.replacingOccurrences(of: "{{clipboard}}", with: context.clipboard)
        out = out.replacingOccurrences(of: "{{name}}", with: context.username)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        out = out.replacingOccurrences(of: "{{date}}", with: df.string(from: context.date))
        return out
    }
}
