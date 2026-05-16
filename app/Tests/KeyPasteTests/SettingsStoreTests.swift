import XCTest
@testable import KeyPaste

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suite: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "kp-settings-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        suite.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsWhenNothingPersisted() {
        let store = SettingsStore(defaults: suite)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertEqual(store.pasteRestoreDelay,
                       SettingsStore.defaultPasteRestoreDelay)
    }

    func testWritesAreObservedInDefaults() {
        let store = SettingsStore(defaults: suite)
        store.launchAtLogin = true
        store.pasteRestoreDelay = 0.5
        XCTAssertTrue(suite.bool(forKey: SettingsStore.launchAtLoginKey))
        XCTAssertEqual(suite.double(forKey: SettingsStore.pasteRestoreDelayKey),
                       0.5)
    }

    func testReloadFromExistingDefaults() {
        suite.set(true, forKey: SettingsStore.launchAtLoginKey)
        suite.set(0.7, forKey: SettingsStore.pasteRestoreDelayKey)
        let store = SettingsStore(defaults: suite)
        XCTAssertTrue(store.launchAtLogin)
        XCTAssertEqual(store.pasteRestoreDelay, 0.7)
    }

    func testPasteRestoreDelayClampsToRange() {
        let store = SettingsStore(defaults: suite)
        store.pasteRestoreDelay = 5.0   // way above max
        XCTAssertEqual(store.pasteRestoreDelay,
                       SettingsStore.pasteRestoreDelayRange.upperBound)
        store.pasteRestoreDelay = -1.0  // below min
        XCTAssertEqual(store.pasteRestoreDelay,
                       SettingsStore.pasteRestoreDelayRange.lowerBound)
    }
}
