import XCTest
@testable import KeyPaste

final class SnippetPacksTests: XCTestCase {
    private var tempDir: URL!
    private var store: TriggerStore!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kp-packs-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir,
                                                withIntermediateDirectories: true)
        store = try TriggerStore(directory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testAllPacksAreNonEmpty() {
        XCTAssertFalse(SnippetPacks.all.isEmpty)
        for pack in SnippetPacks.all {
            XCTAssertFalse(pack.entries.isEmpty, "pack '\(pack.id)' has no entries")
            for entry in pack.entries {
                XCTAssertFalse(entry.trigger.isEmpty)
                XCTAssertFalse(entry.content.isEmpty)
            }
        }
    }

    func testInstallIntoEmptyStoreAddsEverything() {
        let pack = SnippetPacks.all.first { $0.id == "dates" }!
        let result = SnippetPacks.install(pack, into: store)
        XCTAssertEqual(result.added, pack.entries.count)
        XCTAssertEqual(result.skipped, 0)

        let loaded = try! store.load()
        XCTAssertEqual(loaded.triggers.count, pack.entries.count)
        XCTAssertEqual(Set(loaded.triggers.map(\.trigger)),
                       Set(pack.entries.map(\.trigger)))
    }

    func testReinstallSamePackSkipsEverything() {
        let pack = SnippetPacks.all.first { $0.id == "identifiers" }!
        _ = SnippetPacks.install(pack, into: store)
        let second = SnippetPacks.install(pack, into: store)
        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(second.skipped, pack.entries.count)
    }

    func testInstallWithOneConflictSkipsOnlyThat() throws {
        let pack = SnippetPack(id: "test",
                               name: "Test",
                               description: "",
                               entries: [
                                .init(trigger: ";a", content: "A", title: ""),
                                .init(trigger: ";b", content: "B", title: ""),
                               ])
        // Pre-seed with ";a".
        var file = TriggerFile.empty()
        file.triggers = [
            Trigger(id: ULID.generate(),
                    trigger: ";a", content: "existing",
                    title: "", scope: nil,
                    createdAt: Date(), updatedAt: Date())
        ]
        try store.save(file)

        let result = SnippetPacks.install(pack, into: store)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
        let reloaded = try! store.load()
        XCTAssertEqual(reloaded.triggers.count, 2)
        // Existing ";a" content must NOT be overwritten.
        let a = reloaded.triggers.first { $0.trigger == ";a" }
        XCTAssertEqual(a?.content, "existing")
    }

    func testInstallPersistsTriggerMetadata() {
        let pack = SnippetPacks.all.first { $0.id == "identifiers" }!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = SnippetPacks.install(pack, into: store, now: now)
        let loaded = try! store.load()
        let t = loaded.triggers.first!
        XCTAssertEqual(t.createdAt, now)
        XCTAssertEqual(t.updatedAt, now)
        XCTAssertEqual(t.id.count, 26, "ULID length")
        XCTAssertNil(t.scope)
    }
}
