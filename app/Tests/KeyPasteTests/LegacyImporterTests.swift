import XCTest
@testable import KeyPaste

final class LegacyImporterTests: XCTestCase {

    func testDecodeEmptyArray() throws {
        let entries = try LegacyImporter.decode("[]".data(using: .utf8)!)
        XCTAssertTrue(entries.isEmpty)
    }

    func testDecodePlainStringContent() throws {
        let json = """
        [
          {"id": "1727186400123", "trigger": "email",
           "content": "user@example.com", "title": "Personal email"}
        ]
        """
        let entries = try LegacyImporter.decode(json.data(using: .utf8)!)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].trigger, "email")
        XCTAssertEqual(entries[0].content, "user@example.com")
        XCTAssertEqual(entries[0].title, "Personal email")
    }

    func testDecodeDictWrappedContent() throws {
        let json = """
        [
          {"id": "1727186500999", "trigger": "sig",
           "content": {"text": "Best,\\n{{name}}"}, "title": ""}
        ]
        """
        let entries = try LegacyImporter.decode(json.data(using: .utf8)!)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].trigger, "sig")
        XCTAssertEqual(entries[0].content, "Best,\n{{name}}")
        XCTAssertEqual(entries[0].title, "")
    }

    func testDecodeMixedContentForms() throws {
        let json = """
        [
          {"id": "1", "trigger": "a", "content": "alpha", "title": ""},
          {"id": "2", "trigger": "b", "content": {"text": "beta"}, "title": "B"}
        ]
        """
        let entries = try LegacyImporter.decode(json.data(using: .utf8)!)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].content, "alpha")
        XCTAssertEqual(entries[1].content, "beta")
        XCTAssertEqual(entries[1].title, "B")
    }

    func testMigrateProducesV2WithFreshUlidAndTimestamps() throws {
        let json = """
        [
          {"id": "x", "trigger": "t1", "content": "c1", "title": "T1"},
          {"id": "y", "trigger": "t2", "content": "c2", "title": ""}
        ]
        """
        let entries = try LegacyImporter.decode(json.data(using: .utf8)!)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let v2 = LegacyImporter.migrate(entries, now: now)

        XCTAssertEqual(v2.schemaVersion, TriggerFile.currentSchemaVersion)
        XCTAssertEqual(v2.updatedAt, now)
        XCTAssertEqual(v2.triggers.count, 2)

        for t in v2.triggers {
            XCTAssertEqual(t.id.count, 26, "ULID should be 26 chars")
            XCTAssertEqual(t.createdAt, now)
            XCTAssertEqual(t.updatedAt, now)
            XCTAssertNil(t.scope)
        }
        XCTAssertEqual(Set(v2.triggers.map(\.id)).count, 2,
                       "ULIDs must be unique even with the same `now`")
    }

    func testStoreAutoMigratesLegacyFileOnLoad() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KeyPasteStoreTest-\(UUID().uuidString)",
                                    isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let legacy = """
        [
          {"id": "1727186400123", "trigger": "email",
           "content": "user@example.com", "title": "P"},
          {"id": "1727186500999", "trigger": "sig",
           "content": {"text": "X"}, "title": ""}
        ]
        """.data(using: .utf8)!
        try FileManager.default.createDirectory(at: tmp,
                                                withIntermediateDirectories: true)
        try legacy.write(to: tmp.appendingPathComponent("triggers.json"))

        let store = try TriggerStore(directory: tmp)
        let loaded = try store.load()

        XCTAssertEqual(loaded.schemaVersion, TriggerFile.currentSchemaVersion)
        XCTAssertEqual(loaded.triggers.count, 2)
        XCTAssertEqual(Set(loaded.triggers.map(\.trigger)), Set(["email", "sig"]))

        let backup = tmp.appendingPathComponent("triggers.legacy.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path),
                      "Legacy backup file must be created before overwrite")
        XCTAssertEqual(try Data(contentsOf: backup), legacy,
                       "Backup must be byte-identical to the original")

        let reloaded = try store.load()
        XCTAssertEqual(reloaded.schemaVersion, TriggerFile.currentSchemaVersion)
        XCTAssertEqual(reloaded.triggers.map(\.id), loaded.triggers.map(\.id),
                       "Second load must not re-migrate")
    }
}

final class ULIDTests: XCTestCase {
    private let alphabet: Set<Character> =
        Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    func testLengthAndAlphabet() {
        for _ in 0..<20 {
            let id = ULID.generate()
            XCTAssertEqual(id.count, 26)
            XCTAssertTrue(id.allSatisfy { alphabet.contains($0) },
                          "ULID contained char outside Crockford base32: \(id)")
        }
    }

    func testUniquenessWithSameTimestamp() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var seen = Set<String>()
        for _ in 0..<100 { seen.insert(ULID.generate(now: now)) }
        XCTAssertEqual(seen.count, 100)
    }

    func testTimestampPrefixIsAscending() {
        let earlier = ULID.generate(now: Date(timeIntervalSince1970: 1_700_000_000))
        let later   = ULID.generate(now: Date(timeIntervalSince1970: 1_700_000_001))
        XCTAssertLessThan(String(earlier.prefix(10)), String(later.prefix(10)))
    }
}
