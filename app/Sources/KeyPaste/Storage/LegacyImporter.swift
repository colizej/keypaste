import Foundation

// Migrates v1 triggers.json (from the legacy Rust+Swift KeyPaste) into v2.
//
// Legacy schema:
//   [
//     {"id": "<ms-string>", "trigger": "...", "title": "...",
//      "content": "..." | {"text": "..."}}
//   ]
//
// Notes:
//   - The legacy `id` is dropped: v2 uses a fresh ULID per entry.
//   - `content` may be a plain String OR a nested object {"text": String}.
//   - No timestamps in v1; createdAt/updatedAt default to `now` at migration.

enum LegacyImporter {
    struct LegacyEntry: Decodable {
        let trigger: String
        let content: String
        let title: String

        private enum CodingKeys: String, CodingKey {
            case trigger, content, title
        }

        private enum ContentKeys: String, CodingKey {
            case text
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.trigger = try c.decode(String.self, forKey: .trigger)
            self.title = (try c.decodeIfPresent(String.self, forKey: .title)) ?? ""

            if let asString = try? c.decode(String.self, forKey: .content) {
                self.content = asString
            } else {
                let sub = try c.nestedContainer(keyedBy: ContentKeys.self,
                                                forKey: .content)
                self.content = try sub.decode(String.self, forKey: .text)
            }
        }
    }

    static func decode(_ data: Data) throws -> [LegacyEntry] {
        try JSONDecoder().decode([LegacyEntry].self, from: data)
    }

    static func migrate(_ entries: [LegacyEntry],
                        now: Date = Date()) -> TriggerFile {
        let triggers = entries.map { entry in
            Trigger(
                id: ULID.generate(now: now),
                trigger: entry.trigger,
                content: entry.content,
                title: entry.title,
                scope: nil,
                createdAt: now,
                updatedAt: now
            )
        }
        return TriggerFile(
            schemaVersion: TriggerFile.currentSchemaVersion,
            updatedAt: now,
            triggers: triggers
        )
    }
}
