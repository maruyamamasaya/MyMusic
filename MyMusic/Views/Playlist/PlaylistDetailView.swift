import SwiftUI

struct PlaylistDetailView: View {
    let title: String
    var body: some View { EmptyStateView(icon: "music.note.list", title: "No Songs", message: "Songs added to this playlist will appear here.").navigationTitle(title) }
}
