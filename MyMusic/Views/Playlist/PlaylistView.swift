import SwiftUI

struct PlaylistView: View {
    var body: some View { NavigationStack { List { NavigationLink("Favorites", systemImage: "heart", destination: PlaylistDetailView(title: "Favorites")); NavigationLink("Recently Played", systemImage: "clock", destination: PlaylistDetailView(title: "Recently Played")) }.navigationTitle("Playlists") } }
}
