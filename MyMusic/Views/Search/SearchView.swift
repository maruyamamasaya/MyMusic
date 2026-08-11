import SwiftUI

struct SearchView: View {
    @State private var query = ""
    var body: some View { NavigationStack { EmptyStateView(icon: "magnifyingglass", title: query.isEmpty ? "Search Your Library" : "No Results", message: query.isEmpty ? "Find tracks, albums, artists, and playlists." : "Try another search term.").navigationTitle("Search").searchable(text: $query, prompt: "Tracks, albums, artists, playlists") } }
}
