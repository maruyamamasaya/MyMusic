import XCTest
@testable import MyMusic

@MainActor
final class GenreDisplayPresetOrderingTests: XCTestCase {
    func testReorderedPresetsPersistAcrossStoreReload() throws {
        let suiteName = "GenreDisplayPresetOrderingTests-\(UUID())"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: userDefaults)
        store.saveGenreDisplayPreset(named: "リラックス", enabledGenreNames: ["Ambient"])
        store.saveGenreDisplayPreset(named: "集中", enabledGenreNames: ["Classical"])
        store.saveGenreDisplayPreset(named: "朝", enabledGenreNames: ["Pop"])

        store.moveGenreDisplayPresets(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        XCTAssertEqual(store.genreDisplayPresets.map(\.name), ["朝", "リラックス", "集中"])
        let reloadedStore = LibraryStore(userDefaults: userDefaults)
        XCTAssertEqual(reloadedStore.genreDisplayPresets.map(\.name), ["朝", "リラックス", "集中"])
    }
}
