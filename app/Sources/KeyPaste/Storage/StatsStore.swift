import Foundation

// Per-trigger fire statistics. Lives next to triggers.json as a
// separate stats.json so the Trigger schema stays stable across
// version bumps and so an export of triggers doesn't drag along usage
// data (which is private and machine-local).
//
// recordFire saves synchronously on every fire. At human typing rates
// (~tens of fires per minute, peak) the atomic write is cheap. If
// profiling ever shows it as a bottleneck, swap in a debounced
// scheduler — the test contract only cares about durable persistence,
// not when the write happens.

final class StatsStore {
    enum StoreError: Error {
        case writeFailed(Error)
        case decodeFailed(Error)
    }

    struct Entry: Codable, Equatable {
        var fireCount: Int = 0
        var lastFiredAt: Date? = nil
    }

    struct StatsFile: Codable {
        var schemaVersion: Int
        var entries: [String: Entry]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case entries
        }

        static let currentSchemaVersion = 1
        static func empty() -> StatsFile {
            StatsFile(schemaVersion: currentSchemaVersion, entries: [:])
        }
    }

    static let filename = "stats.json"

    private let fileURL: URL
    private(set) var entries: [String: Entry] = [:]

    init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(Self.filename)
        load()
    }

    func recordFire(triggerID: String, at: Date = Date()) {
        var entry = entries[triggerID] ?? Entry()
        entry.fireCount += 1
        entry.lastFiredAt = at
        entries[triggerID] = entry
        persist()
    }

    func entry(for triggerID: String) -> Entry? {
        entries[triggerID]
    }

    var totalFires: Int {
        entries.values.reduce(0) { $0 + $1.fireCount }
    }

    func reset() {
        entries.removeAll()
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let file = try? decoder.decode(StatsFile.self, from: data) {
            entries = file.entries
        } else {
            Logger.error("StatsStore: failed to decode \(fileURL.path)")
        }
    }

    private func persist() {
        let file = StatsFile(schemaVersion: StatsFile.currentSchemaVersion,
                             entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Logger.error("StatsStore.persist failed: \(error)")
        }
    }
}
