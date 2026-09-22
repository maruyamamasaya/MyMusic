import Foundation

enum HiResLibraryCatalogService {
    nonisolated static func build(from tracks: [Track]) -> HiResLibraryCatalog {
        let hiResTracks = tracks.filter(\.isEligibleForHiResPlayback)
        guard !hiResTracks.isEmpty else { return .empty }
        let library = MusicLibrary.build(from: hiResTracks)
        return HiResLibraryCatalog(
            tracks: library.tracks,
            albums: library.albums,
            artists: library.artists
        )
    }
}
