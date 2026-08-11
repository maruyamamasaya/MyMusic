import Foundation
import Observation

@MainActor
@Observable
final class PlaylistStore {
    private(set) var playlists: [Playlist] = []
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let persistence: PlaylistPersistenceServicing
    private var saveTask: Task<Void, Never>?

    init(persistence: PlaylistPersistenceServicing? = nil) {
        self.persistence = persistence ?? PlaylistPersistenceService()
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        do {
            playlists = try await persistence.load().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "Playlists could not be loaded: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createPlaylist(named name: String) -> Playlist.ID? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let now = Date()
        let playlist = Playlist(id: UUID(), name: trimmedName, trackIDs: [], createdAt: now, updatedAt: now)
        playlists.insert(playlist, at: 0)
        persist()
        return playlist.id
    }

    func deletePlaylist(id: Playlist.ID) {
        playlists.removeAll { $0.id == id }
        persist()
    }

    func renamePlaylist(id: Playlist.ID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        update(id) { $0.name = trimmedName }
    }

    func addTrack(_ track: Track, to playlistID: Playlist.ID) {
        update(playlistID) { playlist in
            guard !playlist.trackIDs.contains(track.id) else { return }
            playlist.trackIDs.append(track.id)
        }
    }

    func removeTrack(_ trackID: Track.ID, from playlistID: Playlist.ID) {
        update(playlistID) { $0.trackIDs.removeAll { $0 == trackID } }
    }

    func playlist(id: Playlist.ID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    func contains(_ trackID: Track.ID, in playlistID: Playlist.ID) -> Bool {
        playlist(id: playlistID)?.trackIDs.contains(trackID) == true
    }

    func tracks(for playlistID: Playlist.ID, in libraryTracks: [Track]) -> [Track] {
        guard let playlist = playlist(id: playlistID) else { return [] }
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryTracks.map { ($0.id, $0) })
        return playlist.trackIDs.compactMap { tracksByID[$0] }
    }

    func dismissError() { errorMessage = nil }

    private func update(_ id: Playlist.ID, change: (inout Playlist) -> Void) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        let previous = playlists[index]
        change(&playlists[index])
        guard playlists[index] != previous else { return }
        playlists[index].updatedAt = Date()
        persist()
    }

    private func persist() {
        let snapshot = playlists
        saveTask?.cancel()
        saveTask = Task { [weak self, persistence] in
            do {
                try await persistence.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = "Playlists could not be saved: \(error.localizedDescription)"
            }
        }
    }
}
