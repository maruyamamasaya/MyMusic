import XCTest
@testable import MyMusic

final class HiResLibraryCatalogTests: XCTestCase {
    func testHiResEligibilityUsesGenreOrStoredAudioResolution() {
        let taggedAAC = makeTrack(
            title: "Tagged",
            genre: "Classical; ハイレゾ",
            format: AudioFormat(codec: .aac, bitRate: 256_000, sampleRate: 44_100, bitDepth: nil, channels: 2)
        )
        let highResolutionALAC = makeTrack(
            title: "Technical",
            genre: "Classical",
            format: AudioFormat(codec: .alac, bitRate: nil, sampleRate: 192_000, bitDepth: 24, channels: 2)
        )
        let cdQualityALAC = makeTrack(
            title: "CD",
            genre: "Classical",
            format: AudioFormat(codec: .alac, bitRate: nil, sampleRate: 44_100, bitDepth: 16, channels: 2)
        )

        XCTAssertTrue(taggedAAC.isEligibleForHiResPlayback)
        XCTAssertTrue(highResolutionALAC.isEligibleForHiResPlayback)
        XCTAssertFalse(cdQualityALAC.isEligibleForHiResPlayback)
        XCTAssertFalse(taggedAAC.isEligibleForRegularPlayback)
        XCTAssertTrue(cdQualityALAC.isEligibleForRegularPlayback)
    }

    func testWorkGenreTakesPrecedenceOverHiResClassification() {
        let workHiRes = makeTrack(
            title: "Work",
            genre: "\(Track.workPlaybackGenre); \(Track.hiResPlaybackGenre)",
            format: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 96_000, bitDepth: 24, channels: 2)
        )

        XCTAssertTrue(workHiRes.isEligibleForWorkPlayback)
        XCTAssertFalse(workHiRes.isEligibleForHiResPlayback)
        XCTAssertFalse(workHiRes.isEligibleForRegularPlayback)
    }

    func testCatalogContainsOnlyHiResTracksAndCollections() {
        let hiRes = makeTrack(
            title: "Hi-Res",
            genre: "Jazz",
            format: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 96_000, bitDepth: 24, channels: 2)
        )
        let regular = makeTrack(
            title: "Regular",
            genre: "Jazz",
            format: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 44_100, bitDepth: 16, channels: 2)
        )

        let catalog = HiResLibraryCatalogService.build(from: [regular, hiRes])

        XCTAssertEqual(catalog.tracks.map(\.id), [hiRes.id])
        XCTAssertEqual(catalog.albums.flatMap(\.trackIDs), [hiRes.id])
        XCTAssertEqual(catalog.artists.flatMap(\.trackIDs), [hiRes.id])
    }

    func testPresentationSnapshotSeparatesHiResFromRegularLibrary() async throws {
        let hiRes = makeTrack(
            title: "Hi-Res",
            genre: "Jazz",
            format: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 96_000, bitDepth: 24, channels: 2)
        )
        let regular = makeTrack(
            title: "Regular",
            genre: "Jazz",
            format: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 44_100, bitDepth: 16, channels: 2)
        )

        let snapshot = try await GenreLibraryFilterService().filteredLibrary(
            from: [regular, hiRes],
            disabledGenreNames: [],
            unassignedGenreKey: "unassigned"
        )

        XCTAssertEqual(snapshot.library.tracks.map(\.id), [regular.id])
        XCTAssertEqual(snapshot.hiResLibraryCatalog.tracks.map(\.id), [hiRes.id])
        XCTAssertTrue(snapshot.workLibraryCatalog.tracks.isEmpty)
    }

    private func makeTrack(title: String, genre: String, format: AudioFormat) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist \(title)",
            albumTitle: "Album \(title)",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"),
            genre: genre,
            audioFormat: format
        )
    }
}
