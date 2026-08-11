import Foundation
import Observation

@Observable
final class PlaylistStore {
    private(set) var playlists: [Playlist] = []

    func createPlaylist(named name: String) {
        let now = Date()
        playlists.append(Playlist(id: UUID(), name: name, trackIDs: [], createdAt: now, updatedAt: now))
    }
    func deletePlaylist(id: Playlist.ID) { playlists.removeAll { $0.id == id } }
    func addTrack(_ trackID: Track.ID, to playlistID: Playlist.ID) { update(playlistID) { $0.trackIDs.append(trackID) } }
    func removeTrack(_ trackID: Track.ID, from playlistID: Playlist.ID) { update(playlistID) { $0.trackIDs.removeAll { $0 == trackID } } }
    private func update(_ id: Playlist.ID, change: (inout Playlist) -> Void) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        change(&playlists[index]); playlists[index].updatedAt = Date()
    }
}
