import XCTest
@testable import KeyPaste

final class StatsStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kp-stats-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testEmptyStoreReturnsZeroes() throws {
        let s = try StatsStore(directory: tempDir)
        XCTAssertEqual(s.totalFires, 0)
        XCTAssertNil(s.entry(for: "anything"))
    }

    func testRecordFireIncrementsCount() throws {
        let s = try StatsStore(directory: tempDir)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        s.recordFire(triggerID: "T1", at: now)
        s.recordFire(triggerID: "T1", at: now.addingTimeInterval(60))
        s.recordFire(triggerID: "T2", at: now)

        XCTAssertEqual(s.entry(for: "T1")?.fireCount, 2)
        XCTAssertEqual(s.entry(for: "T2")?.fireCount, 1)
        XCTAssertEqual(s.totalFires, 3)
    }

    func testRecordFireUpdatesLastFiredAt() throws {
        let s = try StatsStore(directory: tempDir)
        let early = Date(timeIntervalSince1970: 1_000_000_000)
        let later = Date(timeIntervalSince1970: 2_000_000_000)
        s.recordFire(triggerID: "T", at: early)
        s.recordFire(triggerID: "T", at: later)
        XCTAssertEqual(s.entry(for: "T")?.lastFiredAt, later)
    }

    func testPersistenceRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let s = try StatsStore(directory: tempDir)
            s.recordFire(triggerID: "T1", at: now)
            s.recordFire(triggerID: "T1", at: now)
            s.recordFire(triggerID: "T2", at: now)
        }
        let reload = try StatsStore(directory: tempDir)
        XCTAssertEqual(reload.entry(for: "T1")?.fireCount, 2)
        XCTAssertEqual(reload.entry(for: "T2")?.fireCount, 1)
        XCTAssertEqual(reload.totalFires, 3)
    }

    func testResetClearsAllEntries() throws {
        let s = try StatsStore(directory: tempDir)
        s.recordFire(triggerID: "T1")
        s.recordFire(triggerID: "T2")
        s.reset()
        XCTAssertEqual(s.totalFires, 0)

        let reload = try StatsStore(directory: tempDir)
        XCTAssertEqual(reload.totalFires, 0, "reset persists")
    }
}
