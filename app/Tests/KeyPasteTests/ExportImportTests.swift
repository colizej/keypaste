import XCTest
@testable import KeyPaste

final class ExportImportTests: XCTestCase {
    private var tempDir: URL!
    private var store: TriggerStore!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kp-export-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir,
                                                withIntermediateDirectories: true)
        store = try TriggerStore(directory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func sampleTrigger(_ key: String, _ content: String = "x") -> Trigger {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return Trigger(id: ULID.generate(now: now),
                       trigger: key, content: content,
                       title: "", scope: nil,
                       createdAt: now, updatedAt: now)
    }

    func testExportThenImportRoundTrip() throws {
        var file = TriggerFile.empty()
        file.triggers = [sampleTrigger(";a", "alpha"),
                         sampleTrigger(";b", "beta")]
        try store.save(file)

        let exportURL = tempDir.appendingPathComponent("export.json")
        try ExportImport.export(try store.load(), to: exportURL)

        let destDir = tempDir.appendingPathComponent("dest", isDirectory: true)
        let dest = try TriggerStore(directory: destDir)
        let result = try ExportImport.importFile(at: exportURL, into: dest)

        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.skipped, 0)
        let loaded = try dest.load()
        XCTAssertEqual(Set(loaded.triggers.map(\.trigger)), [";a", ";b"])
        XCTAssertEqual(Set(loaded.triggers.map(\.content)), ["alpha", "beta"])
    }

    func testImportSkipsConflicts() throws {
        // store has ;a; import contains ;a and ;b
        var file = TriggerFile.empty()
        file.triggers = [sampleTrigger(";a", "existing")]
        try store.save(file)

        let payload: [Trigger] = [sampleTrigger(";a", "incoming"),
                                  sampleTrigger(";b", "new")]
        let result = ExportImport.merge(payload, into: store)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)

        let reloaded = try store.load()
        let a = reloaded.triggers.first(where: { $0.trigger == ";a" })
        XCTAssertEqual(a?.content, "existing", "user data never overwritten")
        XCTAssertTrue(reloaded.triggers.contains(where: { $0.trigger == ";b" }))
    }

    func testDecodeAcceptsBareTriggerArray() throws {
        let bare: [Trigger] = [sampleTrigger(";a"), sampleTrigger(";b")]
        let data = try JSONEncoder.iso8601Pretty().encode(bare)
        let decoded = try ExportImport.decode(data)
        XCTAssertEqual(decoded.count, 2)
    }

    func testDecodeAcceptsV2TriggerFile() throws {
        var file = TriggerFile.empty()
        file.triggers = [sampleTrigger(";a")]
        let data = try JSONEncoder.iso8601Pretty().encode(file)
        let decoded = try ExportImport.decode(data)
        XCTAssertEqual(decoded.count, 1)
    }

    func testDecodeFallsBackToLegacyV1Format() throws {
        let legacyJSON = """
        [
          {"id": "1", "trigger": "old", "content": "value", "title": "T"}
        ]
        """
        let decoded = try ExportImport.decode(Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger, "old")
        XCTAssertEqual(decoded[0].content, "value")
    }

    func testDecodeUnsupportedThrows() {
        let garbage = Data("definitely not json".utf8)
        XCTAssertThrowsError(try ExportImport.decode(garbage))
    }
}

private extension JSONEncoder {
    static func iso8601Pretty() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
