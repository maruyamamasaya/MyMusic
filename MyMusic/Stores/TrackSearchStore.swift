import Foundation
import Observation

@MainActor
@Observable
final class TrackSearchStore {
    private(set) var results: [Track] = []
    private(set) var resultAlbums: [Album] = []
    private(set) var resultArtists: [Artist] = []

    private let debounceDuration: Duration
    private let worker: TrackSearchWorker
    private var searchTask: Task<Void, Never>?

    init(
        debounceDuration: Duration = .milliseconds(225),
        searchService: TrackSearchService? = nil
    ) {
        self.debounceDuration = debounceDuration
        self.worker = TrackSearchWorker(searchService: searchService ?? TrackSearchService())
    }

    func update(
        tracks: [Track],
        albums: [Album],
        artists: [Artist],
        query: String,
        filter: TrackSearchFilter,
        historyEntries: [Track.ID: PlaybackHistory],
        preferenceEntries: [Track.ID: TrackPreference] = [:]
    ) {
        searchTask?.cancel()
        results = []
        resultAlbums = []
        resultArtists = []

        let hasSearchConditions = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filter.hasConditions
        guard hasSearchConditions else {
            return
        }

        let request = TrackSearchRequest(
            tracks: tracks,
            albums: albums,
            artists: artists,
            query: query,
            filter: filter,
            historyEntries: historyEntries,
            preferenceEntries: preferenceEntries
        )
        searchTask = Task { [weak self, debounceDuration, worker] in
            do {
                try await Task.sleep(for: debounceDuration)
                try Task.checkCancellation()
                let output = await worker.search(request)
                try Task.checkCancellation()
                guard let self else { return }
                results = output.tracks
                resultAlbums = output.albums
                resultArtists = output.artists
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }
}

private struct TrackSearchRequest: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let query: String
    let filter: TrackSearchFilter
    let historyEntries: [Track.ID: PlaybackHistory]
    let preferenceEntries: [Track.ID: TrackPreference]
}

private struct TrackSearchOutput: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
}

actor TrackSearchWorker {
    let searchService: TrackSearchService

    nonisolated init(searchService: TrackSearchService = TrackSearchService()) {
        self.searchService = searchService
    }

    func search(
        tracks: [Track],
        query: String,
        filter: TrackSearchFilter,
        historyEntries: [Track.ID: PlaybackHistory],
        preferenceEntries: [Track.ID: TrackPreference] = [:]
    ) -> [Track] {
        searchService.search(
            tracks: tracks,
            query: query,
            filter: filter,
            historyEntries: historyEntries,
            preferenceEntries: preferenceEntries
        )
    }

    fileprivate func search(_ request: TrackSearchRequest) -> TrackSearchOutput {
        let tracks = search(
            tracks: request.tracks,
            query: request.query,
            filter: request.filter,
            historyEntries: request.historyEntries,
            preferenceEntries: request.preferenceEntries
        )
        guard !Task.isCancelled else { return TrackSearchOutput(tracks: [], albums: [], artists: []) }

        let trackIDs = Set(tracks.map(\.id))
        let albums = request.albums.filter { album in
            album.trackIDs.contains { trackIDs.contains($0) }
        }
        guard !Task.isCancelled else { return TrackSearchOutput(tracks: [], albums: [], artists: []) }
        let artists = request.artists.filter { artist in
            artist.trackIDs.contains { trackIDs.contains($0) }
        }
        return TrackSearchOutput(tracks: tracks, albums: albums, artists: artists)
    }
}
