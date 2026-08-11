import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    var body: some View { ScrollView { VStack(spacing: 24) { Image(systemName: "person.circle.fill").font(.system(size: 100)).foregroundStyle(.secondary); Text(artist.name).font(.largeTitle.bold()); SectionHeaderView(title: "Albums"); EmptyStateView(icon: "square.stack", title: "No Albums", message: "Albums will appear here.") }.padding() }.navigationTitle(artist.name).navigationBarTitleDisplayMode(.inline) }
}
