import XCTest
@testable import KeyPaste

// Covers TriggerStore behavior not already exercised by LegacyImporterTests:
//   - empty-directory load returns empty v2 file
//   - save() fires the onSave callback
//   - v2 load does NOT create a legacy .bak file
final class TriggerStoreMigrationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kp-store-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadOnEmptyDirectoryReturnsEmptyV2File() throws {
        let store = try TriggerStore(directory: tempDir)
        let file = try store.load()
        XCTAssertEqual(file.schemaVersion, TriggerFile.currentSchemaVersion)
        XCTAssertTrue(file.triggers.isEmpty)
    }

    func testSaveFiresOnSaveCallbackWithLatestSnapshot() throws {
        let store = try TriggerStore(directory: tempDir)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trigger = Trigger(id: ULID.generate(now: now),
                              trigger: "hi", content: "hello",
                              title: "Greeting", scope: nil,
                              createdAt: now, updatedAt: now)
        var file = TriggerFile.empty()
        file.triggers = [trigger]

        var notified: TriggerFile?
        store.onSave = { notified = $0 }
        try store.save(file)

        XCTAssertEqual(notified?.triggers.first?.trigger, "hi")
        XCTAssertEqual(notified?.triggers.first?.id, trigger.id)
    }

    func testLoadingV2FileDoesNotCreateLegacyBackup() throws {
        let store = try TriggerStore(directory: tempDir)
        try store.save(TriggerFile.empty())
        _ = try store.load()

        let backup = tempDir.appendingPathComponent("triggers.legacy.json.bak")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
    }
}
