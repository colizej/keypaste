import Foundation

// Trigger model. v2 schema with explicit timestamps and scope reserved
// for future per-app filtering.

struct Trigger: Codable, Identifiable, Equatable {
    let id: String          // ULID, sortable
    var trigger: String
    var content: String
    var title: String
    var scope: String?      // nullable; future: bundle ID restriction
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, trigger, content, title, scope
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TriggerFile: Codable {
    let schemaVersion: Int
    var updatedAt: Date
    var triggers: [Trigger]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case updatedAt = "updated_at"
        case triggers
    }

    static let currentSchemaVersion = 2

    static func empty() -> TriggerFile {
        TriggerFile(schemaVersion: currentSchemaVersion,
                    updatedAt: Date(),
                    triggers: [])
    }
}
