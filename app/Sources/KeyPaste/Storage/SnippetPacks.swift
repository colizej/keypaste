import Foundation

// Built-in snippet packs the user can install with one click from
// Settings. Triggers shipped here all use the `;`-prefix convention so
// they won't collide with normal words typed mid-sentence (instant-fire
// model — see feedback_firing_mode memory).
//
// `install(_:into:)` is idempotent on the trigger-key axis: re-running
// the same pack a second time adds nothing. Conflicts with the user's
// existing triggers are skipped silently (logged), never overwritten.

struct SnippetPack: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let entries: [Entry]

    struct Entry: Equatable {
        let trigger: String
        let content: String
        let title: String
    }
}

enum SnippetPacks {
    static let all: [SnippetPack] = [
        SnippetPack(
            id: "dates",
            name: "Dates & Times",
            description: "Quick inserts for today, now, tomorrow, weekday.",
            entries: [
                .init(trigger: ";today",    content: "{{date}}",       title: "Today (yyyy-MM-dd)"),
                .init(trigger: ";now",      content: "{{datetime}}",   title: "Now (date + time)"),
                .init(trigger: ";time",     content: "{{time}}",       title: "Current time"),
                .init(trigger: ";tomorrow", content: "{{date:+1d}}",   title: "Tomorrow"),
                .init(trigger: ";yesterday",content: "{{date:-1d}}",   title: "Yesterday"),
                .init(trigger: ";weekday",  content: "{{weekday}}",    title: "Day of week"),
                .init(trigger: ";datelong", content: "{{date:long}}",  title: "Long date"),
            ]
        ),
        SnippetPack(
            id: "identifiers",
            name: "Identifiers",
            description: "Fresh UUIDs and other unique IDs.",
            entries: [
                .init(trigger: ";uuid", content: "{{uuid}}", title: "Fresh UUID"),
            ]
        ),
        SnippetPack(
            id: "sql",
            name: "Code: SQL",
            description: "Skeleton SELECT / INSERT / UPDATE / DELETE.",
            entries: [
                .init(trigger: ";sel",
                      content: "SELECT {{cursor}}\nFROM ;",
                      title: "SELECT skeleton"),
                .init(trigger: ";ins",
                      content: "INSERT INTO {{cursor}} ()\nVALUES ();",
                      title: "INSERT skeleton"),
                .init(trigger: ";upd",
                      content: "UPDATE {{cursor}}\nSET \nWHERE ;",
                      title: "UPDATE skeleton"),
                .init(trigger: ";delf",
                      content: "DELETE FROM {{cursor}}\nWHERE ;",
                      title: "DELETE skeleton"),
            ]
        ),
        SnippetPack(
            id: "python",
            name: "Code: Python",
            description: "def / class / try-except / __main__ guard.",
            entries: [
                .init(trigger: ";pydef",
                      content: "def {{cursor}}():\n    pass",
                      title: "Python def"),
                .init(trigger: ";pyclass",
                      content: "class {{cursor}}:\n    def __init__(self):\n        pass",
                      title: "Python class"),
                .init(trigger: ";pytry",
                      content: "try:\n    {{cursor}}\nexcept Exception as e:\n    raise",
                      title: "try / except"),
                .init(trigger: ";pymain",
                      content: "if __name__ == \"__main__\":\n    {{cursor}}",
                      title: "if __main__"),
            ]
        ),
        SnippetPack(
            id: "web",
            name: "Code: HTML & Markdown",
            description: "HTML5 doctype, Markdown link / image / code.",
            entries: [
                .init(trigger: ";html5",
                      content: """
                      <!DOCTYPE html>
                      <html lang="en">
                      <head>
                          <meta charset="UTF-8">
                          <title>{{cursor}}</title>
                      </head>
                      <body>
                      </body>
                      </html>
                      """,
                      title: "HTML5 boilerplate"),
                .init(trigger: ";mdlink",
                      content: "[{{cursor}}]()",
                      title: "Markdown link"),
                .init(trigger: ";mdimg",
                      content: "![{{cursor}}]()",
                      title: "Markdown image"),
                .init(trigger: ";mdcode",
                      content: "```\n{{cursor}}\n```",
                      title: "Markdown code block"),
            ]
        ),
        SnippetPack(
            id: "lorem",
            name: "Lorem Ipsum",
            description: "Placeholder text for mockups.",
            entries: [
                .init(trigger: ";lorem",
                      content: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                      title: "Lorem ipsum sentence"),
                .init(trigger: ";lorem3",
                      content: """
                      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

                      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

                      Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
                      """,
                      title: "Three Lorem paragraphs"),
            ]
        ),
    ]

    struct InstallResult: Equatable {
        let added: Int
        let skipped: Int
    }

    @discardableResult
    static func install(_ pack: SnippetPack,
                        into store: TriggerStore,
                        now: Date = Date()) -> InstallResult {
        let file: TriggerFile
        do {
            file = try store.load()
        } catch {
            Logger.error("Pack '\(pack.id)' install: load failed: \(error)")
            return InstallResult(added: 0, skipped: 0)
        }

        let existing = Set(file.triggers.map(\.trigger))
        var copy = file
        var added = 0
        var skipped = 0

        for entry in pack.entries {
            if existing.contains(entry.trigger) {
                skipped += 1
                continue
            }
            copy.triggers.append(Trigger(
                id: ULID.generate(now: now),
                trigger: entry.trigger,
                content: entry.content,
                title: entry.title,
                scope: nil,
                createdAt: now,
                updatedAt: now
            ))
            added += 1
        }

        if added > 0 {
            do { try store.save(copy) } catch {
                Logger.error("Pack '\(pack.id)' install: save failed: \(error)")
                return InstallResult(added: 0, skipped: skipped)
            }
        }
        Logger.info("Pack '\(pack.id)' installed: \(added) added, \(skipped) skipped")
        return InstallResult(added: added, skipped: skipped)
    }
}
