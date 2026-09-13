import XCTest
@testable import MyMusic

@MainActor
final class ListenLaterStoreTests: XCTestCase {
    func testAddedTrackRemainsUntilPlayCountIncreases() async {
        let persistence = ListenLaterMemoryPersistence()
        let store = ListenLaterStore(persistence: persistence)
        let trackID = UUID()

        store.add(trackID: trackID, currentPlayCount: 4)
        store.reconcile(playCounts: [trackID: 4])
        XCTAssertTrue(store.contains(trackID))

        store.reconcile(playCounts: [trackID: 5])
        XCTAssertFalse(store.contains(trackID))
        await store.waitForPendingSave()
        let persistedEntries = await persistence.loadedEntries()
        XCTAssertEqual(persistedEntries, [])
    }

    func testAddingAgainUsesNewPlayCountBaseline() {
        let store = ListenLaterStore(persistence: ListenLaterMemoryPersistence())
        let trackID = UUID()

        store.add(trackID: trackID, currentPlayCount: 2)
        store.remove(trackID)
        store.add(trackID: trackID, currentPlayCount: 7)
        store.reconcile(playCounts: [trackID: 7])

        XCTAssertTrue(store.contains(trackID))
        XCTAssertEqual(store.entries.single?.playCountWhenAdded, 7)
    }

    func testLoadPreservesOrderAndResolvesLibraryTracks() async {
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let persistence = ListenLaterMemoryPersistence(entries: [
            ListenLaterEntry(trackID: second.id, playCountWhenAdded: 1, addedAt: .distantPast),
            ListenLaterEntry(trackID: first.id, playCountWhenAdded: 0, addedAt: .distantPast)
        ])
        let store = ListenLaterStore(persistence: persistence)

        await store.loadIfNeeded()

        XCTAssertEqual(store.tracks(in: [first, second]).map(\.id), [second.id, first.id])
    }

    private func makeTrack(_ title: String) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).wav"),
            relativePath: "\(title).wav"
        )
    }
}

private actor ListenLaterMemoryPersistence: ListenLaterPersistenceServicing {
    private var entries: [ListenLaterEntry]

    init(entries: [ListenLaterEntry] = []) {
        self.entries = entries
    }

    func load() async throws -> [ListenLaterEntry] { entries }
    func save(_ entries: [ListenLaterEntry]) async throws { self.entries = entries }
    func loadedEntries() -> [ListenLaterEntry] { entries }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
