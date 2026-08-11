import SwiftUI

struct PlaylistView: View {
    var body: some View { NavigationStack { List { NavigationLink(destination: PlaylistDetailView(title: "Favorites")) { Label("Favorites", systemImage: "heart") }; NavigationLink(destination: PlaylistDetailView(title: "Recently Played")) { Label("Recently Played", systemImage: "clock") } }.navigationTitle("Playlists") } }
}
