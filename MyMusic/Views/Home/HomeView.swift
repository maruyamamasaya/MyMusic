import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 24) { SectionHeaderView(title: "Recently Added"); EmptyStateView(icon: "music.note", title: "No Music", message: "Imported music will appear here.") }.padding() }
                .navigationTitle("Home")
        }
    }
}
