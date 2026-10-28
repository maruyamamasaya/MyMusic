import XCTest
@testable import MyMusic

final class AmbientSelectionPolicyTests: XCTestCase {
    func testCutoffRejectsMissingInvalidAndLowScores() {
        for value: Double? in [nil, .nan, .infinity, -0.1, 0.4999, 1.01] {
            XCTAssertFalse(AmbientSelectionPolicy.includes(value))
        }
        XCTAssertTrue(AmbientSelectionPolicy.includes(0.5))
        XCTAssertTrue(AmbientSelectionPolicy.includes(1))
    }

    func testCandidatesRespectInputScopeAndAllowVocalsWithoutGenreMatching() throws {
        let ambient = track("Atmosphere")
        let low = track("Low")
        let missing = track("Missing")
        let outside = track("Outside tuning")
        let features = try Dictionary(uniqueKeysWithValues: [
            (ambient.id, feature(ambient, score: 0.7)),
            (low.id, feature(low, score: 0.2)),
            (outside.id, feature(outside, score: 1))
        ])
        let result = AmbientSelectionPolicy.candidates(from: [ambient, low, missing, ambient], features: features)
        XCTAssertEqual(result.map(\.id), [ambient.id])
        XCTAssertTrue(AmbientSelectionPolicy.candidates(from: [low, missing], features: features).isEmpty)
        XCTAssertTrue(AmbientSelectionPolicy.candidates(from: [ambient], features: [:]).isEmpty)
    }

    private func track(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 120,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func feature(_ track: Track, score: Double) throws -> TrackFeature {
        let values = try JSONDecoder().decode(TrackFeatureValues.self,
            from: Data("{\"ambient\":\(score),\"vocal\":1,\"instrumental\":0}".utf8))
        return TrackFeature(trackID: track.id,
                            sourceIdentity: TrackFeatureSourceIdentity(relativePath: "song.m4a", fileSize: 1,
                                duration: 120, modificationDate: nil, contentHash: nil,
                                title: nil, artist: nil, album: nil),
                            analysisVersion: 2, analyzedAt: Date(), importedAt: Date(), values: values)
    }
}
