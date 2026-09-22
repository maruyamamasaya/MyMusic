import XCTest
@testable import MyMusic

final class TrackDetailPresentationTests: XCTestCase {
    func testTrackDetailsExposeStoredMetadataAndTechnicalInformation() {
        let track = Track(
            id: UUID(),
            title: "Detailed Track",
            artistName: "Track Artist",
            albumArtistName: "Album Artist",
            albumTitle: "Album",
            duration: 3_661,
            fileURL: URL(fileURLWithPath: "/music/album/track.m4a"),
            relativePath: "album/track.m4a",
            fileSize: 12_345_678,
            trackNumber: 3,
            discNumber: 2,
            year: 2026,
            genre: "Soundtrack",
            composer: "Composer",
            audioFormat: AudioFormat(
                codec: .alac,
                bitRate: 6_749_000,
                sampleRate: 192_000,
                bitDepth: 24,
                channels: 2
            )
        )

        let metadata = Dictionary(uniqueKeysWithValues: TrackDetailPresentation.metadataItems(for: track).map { ($0.id, $0.value) })
        let audio = Dictionary(uniqueKeysWithValues: TrackDetailPresentation.audioItems(for: track).map { ($0.id, $0.value) })
        let file = Dictionary(uniqueKeysWithValues: TrackDetailPresentation.fileItems(for: track).map { ($0.id, $0.value) })

        XCTAssertEqual(metadata["albumArtist"], "Album Artist")
        XCTAssertEqual(metadata["position"], "2 / 3")
        XCTAssertEqual(metadata["duration"], "1:01:01")
        XCTAssertEqual(audio["quality"], "Hi-Res")
        XCTAssertEqual(audio["sampleRate"], "192.0 kHz")
        XCTAssertEqual(audio["bitDepth"], "24 bit")
        XCTAssertEqual(file["fileName"], "track.m4a")
        XCTAssertEqual(file["relativePath"], "album/track.m4a")
    }

    func testFeatureDetailsIncludeAnalysisAndStrongestCategories() {
        let feature = TrackFeature(
            trackID: UUID(),
            sourceIdentity: TrackFeatureSourceIdentity(
                relativePath: "track.m4a",
                fileSize: 1,
                duration: 60,
                modificationDate: nil,
                contentHash: nil,
                title: nil,
                artist: nil,
                album: nil
            ),
            analysisVersion: 4,
            analyzedAt: Date(timeIntervalSince1970: 0),
            importedAt: Date(timeIntervalSince1970: 0),
            values: TrackFeatureValues(
                tempo: 128.25,
                energy: 0.8,
                piano: 0.3,
                ambient: 0.9,
                electronic: 0.7,
                drumAndBass: nil,
                aggressive: nil,
                calm: nil,
                bright: nil,
                dark: nil,
                vocal: nil,
                instrumental: nil,
                additional: nil,
                integratedLUFS: -14.2,
                truePeakDBTP: -1.1,
                normalizationGainDB: 0.2
            )
        )

        let items = Dictionary(uniqueKeysWithValues: TrackDetailPresentation.featureItems(for: feature).map { ($0.id, $0.value) })

        XCTAssertEqual(items["tempo"], "128.2 BPM")
        XCTAssertEqual(items["energy"], "80%")
        XCTAssertEqual(items["feature-ambient"], "90%")
        XCTAssertEqual(items["lufs"], "-14.2 LUFS")
        XCTAssertEqual(items["analysisVersion"], "v4")
    }
}
