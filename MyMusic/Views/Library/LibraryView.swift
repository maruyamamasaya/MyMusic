import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Songs", systemImage: "music.note", destination: SongsView())
                NavigationLink("Albums", systemImage: "square.stack", destination: AlbumsView())
                NavigationLink("Artists", systemImage: "music.mic", destination: ArtistsView())
            }.navigationTitle("Library")
        }
    }
}
