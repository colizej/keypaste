import Foundation

// Lossless JSON export/import of the trigger store.
//
// Export writes the current TriggerFile (v2 schema) verbatim — round-
// trips through TriggerStore.load() on import. Import is more forgiving:
//   1. Try v2 TriggerFile  (our own export format).
//   2. Try a bare [Trigger] array  (a partial dump someone might paste).
//   3. Try legacy v1 (LegacyImporter)  (so the legacy Rust+Swift KeyPaste
//      data can be hand-imported from another machine).
//
// Merge semantics match SnippetPacks: triggers whose key (the typed
// shortcut) already exists in the store are skipped, not overwritten.
// Imported triggers get fresh ULIDs to avoid collisions, but keep their
// original createdAt/updatedAt if present so backup restores look
// identical.
//
// YAML / Espanso / TextExpander format adapters are deliberately left
// out of Sprint 3.3 — they need either a YAML dep (Yams) or a hand-
// rolled mini-parser. Add when someone actually asks.

enum ExportImport {
    enum ImportError: Error {
        case unsupportedFormat
        case readFailed(Error)
    }

    struct ImportResult: Equatable {
        let added: Int
        let skipped: Int
    }

    static func export(_ file: TriggerFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        try data.write(to: url, options: [.atomic])
    }

    @discardableResult
    static func importFile(at url: URL,
                           into store: TriggerStore,
                           now: Date = Date()) throws -> ImportResult {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ImportError.readFailed(error) }
        let incoming = try decode(data)
        return merge(incoming, into: store, now: now)
    }

    static func decode(_ data: Data) throws -> [Trigger] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let file = try? decoder.decode(TriggerFile.self, from: data) {
            return file.triggers
        }
        if let arr = try? decoder.decode([Trigger].self, from: data) {
            return arr
        }
        if let entries = try? LegacyImporter.decode(data) {
            return LegacyImporter.migrate(entries).triggers
        }
        throw ImportError.unsupportedFormat
    }

    static func merge(_ incoming: [Trigger],
                      into store: TriggerStore,
                      now: Date = Date()) -> ImportResult {
        guard var file = try? store.load() else {
            return ImportResult(added: 0, skipped: 0)
        }
        let existing = Set(file.triggers.map(\.trigger))
        var added = 0
        var skipped = 0
        for t in incoming {
            if existing.contains(t.trigger) {
                skipped += 1
                continue
            }
            file.triggers.append(Trigger(
                id: ULID.generate(now: now),
                trigger: t.trigger,
                content: t.content,
                title: t.title,
                scope: t.scope,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt
            ))
            added += 1
        }
        if added > 0 {
            try? store.save(file)
        }
        Logger.info("Import: \(added) added, \(skipped) skipped")
        return ImportResult(added: added, skipped: skipped)
    }
}
