import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    private var recentTracks: [Track] {
        playbackHistoryStore.recentTracks(from: libraryStore.tracks, limit: 10)
    }

    private var favoriteTracks: [Track] {
        playbackHistoryStore.favoriteTracks(from: libraryStore.tracks, limit: 10)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Recently Played") {
                    if recentTracks.isEmpty {
                        ContentUnavailableView("Nothing Played Yet", systemImage: "clock", description: Text("Songs you play will appear here."))
                    } else {
                        trackButtons(recentTracks)
                    }
                }

                Section("Favorites") {
                    if favoriteTracks.isEmpty {
                        ContentUnavailableView("No Favorites", systemImage: "heart", description: Text("Favorite songs will appear here."))
                    } else {
                        trackButtons(favoriteTracks)
                    }
                }
            }
                .navigationTitle("Home")
        }
    }

    @ViewBuilder
    private func trackButtons(_ tracks: [Track]) -> some View {
        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
            Button {
                playerStore.playQueue(tracks, startingAt: index)
            } label: {
                TrackRowView(track: track)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
