import SwiftUI

struct ArtistsView: View {
    let artists: [Artist]
    init(artists: [Artist] = PreviewData.artists) { self.artists = artists }
    var body: some View { List(artists) { artist in NavigationLink(value: artist) { Label(artist.name, systemImage: "person.circle") } }.navigationTitle("Artists").navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) } }
}
