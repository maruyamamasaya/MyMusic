import SwiftUI

struct SongsView: View {
    let tracks: [Track]
    init(tracks: [Track] = PreviewData.tracks) { self.tracks = tracks }
    var body: some View { List(tracks) { TrackRowView(track: $0) }.navigationTitle("Songs") }
}
