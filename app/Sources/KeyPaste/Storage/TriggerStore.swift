import Foundation

// Atomic file storage for triggers.
// Auto-detects and migrates v1 (legacy) files on load.
// Sprint 3 will layer iCloud Key-Value Store sync on top of this.

final class TriggerStore {
    enum StoreError: Error {
        case fileURLUnavailable
        case writeFailed(Error)
        case readFailed(Error)
        case decodeFailed(Error)
    }

    private let fileURL: URL
    private let backupURL: URL

    var directoryURL: URL { fileURL.deletingLastPathComponent() }

    var onSave: ((TriggerFile) -> Void)?

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("KeyPaste", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("triggers.json")
        self.backupURL = dir.appendingPathComponent("triggers.legacy.json.bak")
    }

    init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("triggers.json")
        self.backupURL = directory.appendingPathComponent("triggers.legacy.json.bak")
    }

    func load() throws -> TriggerFile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return TriggerFile.empty()
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StoreError.readFailed(error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let v2 = try? decoder.decode(TriggerFile.self, from: data) {
            return v2
        }

        do {
            let entries = try LegacyImporter.decode(data)
            let migrated = LegacyImporter.migrate(entries)
            try data.write(to: backupURL, options: [.atomic])
            try save(migrated)
            Logger.info("Migrated \(entries.count) triggers from legacy v1 format")
            return migrated
        } catch {
            throw StoreError.decodeFailed(error)
        }
    }

    func save(_ file: TriggerFile) throws {
        var copy = file
        copy.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(copy)
        } catch {
            throw StoreError.writeFailed(error)
        }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StoreError.writeFailed(error)
        }
        onSave?(copy)
    }
}
