import Foundation

enum HomeRepresentativeTrackPolicy {
    static func eligibleArtworkTracks(from tracks: [Track]) -> [Track] {
        tracks.filter {
            $0.isEligibleForRegularPlayback && $0.artworkIdentifier != nil
        }
    }

    static func select(from candidates: [Track], excluding previousTrackID: Track.ID?) -> Track? {
        guard !candidates.isEmpty else { return nil }
        let alternatives = candidates.filter { $0.id != previousTrackID }
        return (alternatives.isEmpty ? candidates : alternatives).randomElement()
    }

    static func placingRepresentativeFirst(
        _ representativeTrack: Track?,
        in shuffledTracks: [Track]
    ) -> [Track] {
        guard let representativeTrack else { return shuffledTracks }
        return [representativeTrack] + shuffledTracks.filter { $0.id != representativeTrack.id }
    }
}
