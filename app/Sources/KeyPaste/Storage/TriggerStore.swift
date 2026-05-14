import Foundation

// Atomic file storage for triggers.
// Sprint 3 will layer iCloud Key-Value Store sync on top of this.

final class TriggerStore {
    enum StoreError: Error {
        case fileURLUnavailable
        case writeFailed(Error)
        case readFailed(Error)
        case decodeFailed(Error)
    }

    private let fileURL: URL

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
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TriggerFile.self, from: data)
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
        let data = try encoder.encode(copy)
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StoreError.writeFailed(error)
        }
    }
}
