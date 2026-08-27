import XCTest
@testable import MyMusic

final class TrackFeatureImportServiceTests: XCTestCase {
    private let service = TrackFeatureImportService()

    func testValidJSONIsAccepted() throws {
        let result = try service.prepareImport(
            data: makeJSON(path: "Artist/Album/song.flac", size: 1_234, duration: 243),
            libraryTracks: []
        )

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.unmatchedCount, 1)
    }

    func testValidJSONMatchesTrackByRelativePathFileSizeAndDuration() throws {
        let track = makeTrack(path: "Artist/Album/song.flac", size: 1_234, duration: 243.0)
        let result = try service.prepareImport(
            data: makeJSON(path: track.relativePath!, size: 1_234, duration: 243.31),
            libraryTracks: [track]
        )

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.matchedCount, 1)
        XCTAssertEqual(result.unmatchedCount, 0)
        XCTAssertEqual(result.ambiguousCount, 0)
        XCTAssertEqual(result.features.first?.trackID, track.id)
        XCTAssertEqual(result.features.first?.values.energy, 0.72)
    }

    func testInvalidJSONIsRejected() {
        XCTAssertThrowsError(try service.prepareImport(data: Data("not-json".utf8), libraryTracks: [])) { error in
            guard case TrackFeatureImportError.invalidJSON = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnsupportedSchemaVersionIsRejected() {
        XCTAssertThrowsError(try service.prepareImport(
            data: makeJSON(path: "song.flac", size: 100, duration: 10, schemaVersion: 2),
            libraryTracks: []
        )) { error in
            guard case TrackFeatureImportError.unsupportedSchemaVersion(2) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testNonMatchingTrackRemainsUnmatched() throws {
        let track = makeTrack(path: "original.flac", size: 100, duration: 10)
        let result = try service.prepareImport(
            data: makeJSON(path: "other.flac", size: 999, duration: 20),
            libraryTracks: [track]
        )

        XCTAssertEqual(result.matchedCount, 0)
        XCTAssertEqual(result.unmatchedCount, 1)
        XCTAssertEqual(result.ambiguousCount, 0)
    }

    func testFallbackWithMultipleSafeCandidatesIsAmbiguous() throws {
        let first = makeTrack(path: "A/song.flac", size: 1_000, duration: 120, title: "Same", artist: "Artist")
        let second = makeTrack(path: "B/song.flac", size: 1_000, duration: 120, title: "Same", artist: "Artist")
        let result = try service.prepareImport(
            data: makeJSON(
                path: "Moved/song.flac",
                size: 1_000,
                duration: 120.2,
                title: "Same",
                artist: "Artist",
                album: nil
            ),
            libraryTracks: [first, second]
        )

        XCTAssertEqual(result.matchedCount, 0)
        XCTAssertEqual(result.unmatchedCount, 0)
        XCTAssertEqual(result.ambiguousCount, 1)
    }

    private func makeTrack(
        path: String,
        size: Int64,
        duration: TimeInterval,
        title: String = "Song",
        artist: String = "Artist"
    ) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: artist,
            albumTitle: "Album",
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(path)"),
            relativePath: path,
            fileSize: size
        )
    }

    fileprivate func makeJSON(
        path: String,
        size: Int64,
        duration: TimeInterval,
        title: String? = "Song",
        artist: String? = "Artist",
        album: String? = "Album",
        schemaVersion: Int = 1,
        analysisVersion: Int = 1,
        energy: Double = 0.72
    ) -> Data {
        var track: [String: Any] = [
            "relativePath": path,
            "fileSize": size,
            "duration": duration,
            "features": ["tempo": 92.4, "energy": energy]
        ]
        if let title { track["title"] = title }
        if let artist { track["artist"] = artist }
        if let album { track["album"] = album }
        let root: [String: Any] = [
            "schemaVersion": schemaVersion,
            "analysisVersion": analysisVersion,
            "generatedAt": "2026-08-27T00:00:00.123Z",
            "tracks": [track]
        ]
        return try! JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }
}

@MainActor
final class TrackFeatureStoreTests: XCTestCase {
    func testReimportUpdatesWithoutCreatingDuplicate() async throws {
        let persistence = InMemoryTrackFeaturePersistence()
        let store = TrackFeatureStore(persistence: persistence)
        let track = makeTrack()
        let helper = TrackFeatureImportServiceTests()

        let first = try await store.import(
            data: helper.makeJSON(
                path: track.relativePath!, size: track.fileSize!, duration: track.duration,
                analysisVersion: 1, energy: 0.25
            ),
            libraryTracks: [track]
        )
        let second = try await store.import(
            data: helper.makeJSON(
                path: track.relativePath!, size: track.fileSize!, duration: track.duration,
                analysisVersion: 2, energy: 0.9
            ),
            libraryTracks: [track]
        )

        XCTAssertEqual(first.insertedCount, 1)
        XCTAssertEqual(second.updatedCount, 1)
        XCTAssertEqual(store.feature(for: track.id)?.analysisVersion, 2)
        XCTAssertEqual(store.feature(for: track.id)?.values.energy, 0.9)
        let snapshot = await persistence.currentSnapshot()
        XCTAssertEqual(snapshot.features.count, 1)
    }

    func testDeleteRemovesOnlyFeaturePersistence() async throws {
        let persistence = InMemoryTrackFeaturePersistence()
        let store = TrackFeatureStore(persistence: persistence)
        let track = makeTrack()
        let helper = TrackFeatureImportServiceTests()
        _ = try await store.import(
            data: helper.makeJSON(path: track.relativePath!, size: track.fileSize!, duration: track.duration),
            libraryTracks: [track]
        )

        try await store.deleteAll()

        XCTAssertFalse(store.hasFeature(track.id))
        XCTAssertNil(store.lastImportDate)
        XCTAssertNil(store.lastImportReport)
        let wasDeleted = await persistence.wasDeleted()
        XCTAssertTrue(wasDeleted)
    }

    func testImportReportKeepsIssueSamplesAndReloads() async throws {
        let persistence = InMemoryTrackFeaturePersistence()
        let store = TrackFeatureStore(persistence: persistence)
        let helper = TrackFeatureImportServiceTests()
        let importDate = Date(timeIntervalSince1970: 1_700_000_000)

        let result = try await store.import(
            data: helper.makeJSON(
                path: "Missing/Album/song.flac",
                size: 9_999,
                duration: 321,
                analysisVersion: 3
            ),
            libraryTracks: [],
            now: importDate
        )

        XCTAssertEqual(result.analysisVersion, 3)
        XCTAssertEqual(result.unmatchedSamplePaths, ["Missing/Album/song.flac"])
        XCTAssertEqual(store.lastImportReport?.unmatchedCount, 1)

        let reloadedStore = TrackFeatureStore(persistence: persistence)
        await reloadedStore.loadIfNeeded()

        XCTAssertEqual(reloadedStore.lastImportReport?.analysisVersion, 3)
        XCTAssertEqual(reloadedStore.lastImportReport?.unmatchedSamplePaths, ["Missing/Album/song.flac"])
        XCTAssertEqual(reloadedStore.lastImportDate, importDate)
    }

    private func makeTrack() -> Track {
        Track(
            id: UUID(),
            title: "Song",
            artistName: "Artist",
            albumTitle: "Album",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/Artist/Album/song.flac"),
            relativePath: "Artist/Album/song.flac",
            fileSize: 4_096
        )
    }
}

final class TrackFeaturePresentationTests: XCTestCase {
    func testBadgesUseThresholdScoreOrderAndMaximumCount() {
        let values = makeValues(
            piano: 0.92,
            ambient: 0.73,
            electronic: 0.31,
            drumAndBass: 0.81,
            calm: 0.84,
            bright: 0.68
        )

        let badges = TrackFeaturePresentation.badgeItems(for: values)

        XCTAssertEqual(badges.map(\.id), ["piano", "calm", "drumAndBass"])
        XCTAssertEqual(badges.map(\.label), ["ピアノ", "穏やか", "DnB"])
    }

    func testBadgesAreHiddenWhenNoCategoryMeetsThreshold() {
        let values = makeValues(piano: 0.67, calm: 0.4)

        XCTAssertTrue(TrackFeaturePresentation.badgeItems(for: values).isEmpty)
    }

    func testThresholdIsInclusiveAndTiesHaveStableOrder() {
        let values = makeValues(piano: 0.68, ambient: 0.68, calm: 0.68)
        XCTAssertEqual(TrackFeaturePresentation.badgeItems(for: values).map(\.id), ["piano", "ambient", "calm"])
    }

    func testInvalidPersistedScoresAreNotDisplayed() {
        let values = makeValues(piano: .nan, ambient: 1.1, calm: -.infinity)
        XCTAssertTrue(TrackFeaturePresentation.categoryItems(for: values).isEmpty)
    }

    private func makeValues(
        piano: Double? = nil,
        ambient: Double? = nil,
        electronic: Double? = nil,
        drumAndBass: Double? = nil,
        calm: Double? = nil,
        bright: Double? = nil
    ) -> TrackFeatureValues {
        TrackFeatureValues(
            tempo: 92,
            energy: 0.5,
            piano: piano,
            ambient: ambient,
            electronic: electronic,
            drumAndBass: drumAndBass,
            aggressive: nil,
            calm: calm,
            bright: bright,
            dark: nil,
            vocal: nil,
            instrumental: nil,
            additional: nil
        )
    }
}

private actor InMemoryTrackFeaturePersistence: TrackFeaturePersistenceServicing {
    private var snapshot = TrackFeaturePersistenceSnapshot(features: [], lastImportDate: nil)
    private var deleted = false

    func load() async throws -> TrackFeaturePersistenceSnapshot { snapshot }

    func save(_ snapshot: TrackFeaturePersistenceSnapshot) async throws {
        self.snapshot = snapshot
        deleted = false
    }

    func deleteAll() async throws {
        snapshot = TrackFeaturePersistenceSnapshot(features: [], lastImportDate: nil)
        deleted = true
    }

    func currentSnapshot() -> TrackFeaturePersistenceSnapshot { snapshot }
    func wasDeleted() -> Bool { deleted }
}
