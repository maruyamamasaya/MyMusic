import XCTest
@testable import MyMusic

final class HomeRepresentativeTrackPolicyTests: XCTestCase {
    func testEligibleArtworkTracksExcludeWorkPlaybackAndMissingArtwork() {
        let regular = makeTrack(title: "Regular", duration: 180, artworkIdentifier: "regular")
        let longForm = makeTrack(title: "Long", duration: Track.longFormMinimumDuration, artworkIdentifier: "long")
        let workGenre = makeTrack(title: "Work", duration: 180, artworkIdentifier: "work", genre: Track.workPlaybackGenre)
        let noArtwork = makeTrack(title: "No Artwork", duration: 180, artworkIdentifier: nil)

        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.eligibleArtworkTracks(
                from: [regular, longForm, workGenre, noArtwork]
            ).map(\.id),
            [regular.id]
        )
    }

    func testSelectionAvoidsImmediatelyPreviousTrackWhenAlternativeExists() {
        let first = makeTrack(title: "First", artworkIdentifier: "first")
        let second = makeTrack(title: "Second", artworkIdentifier: "second")

        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.select(from: [first, second], excluding: first.id)?.id,
            second.id
        )
        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.select(from: [first], excluding: first.id)?.id,
            first.id
        )
    }

    func testRepresentativeIsFirstAndRemovedFromFollowingQueue() {
        let first = makeTrack(title: "First")
        let representative = makeTrack(title: "Representative")
        let last = makeTrack(title: "Last")

        let queue = HomeRepresentativeTrackPolicy.placingRepresentativeFirst(
            representative,
            in: [first, representative, last, representative]
        )

        XCTAssertEqual(queue.map(\.id), [representative.id, first.id, last.id])
    }

    private func makeTrack(
        title: String,
        duration: TimeInterval = 180,
        artworkIdentifier: String? = nil,
        genre: String? = nil
    ) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"),
            artworkIdentifier: artworkIdentifier,
            genre: genre
        )
    }
}
