import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var isFolderImporterPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Music Library") {
                    if libraryStore.hasLibraryFolder {
                        Label(libraryStore.selectedFolderName ?? "Music Folder", systemImage: "folder")
                    } else {
                        ContentUnavailableView(
                            "No Music Folder Selected",
                            systemImage: "folder.badge.questionmark",
                            description: Text("Choose the Artists folder from Files or iCloud Drive.")
                        )
                    }

                    if libraryStore.isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView()
                            Text("Scanning Music Library…")
                            Text("\(libraryStore.scanProgress) tracks currently in library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if libraryStore.hasLibraryFolder {
                    Section("Browse") {
                        NavigationLink(value: LibraryDestination.songs) { countRow("Songs", systemImage: "music.note", count: libraryStore.tracks.count) }
                        NavigationLink(value: LibraryDestination.albums) { countRow("Albums", systemImage: "square.stack", count: libraryStore.albums.count) }
                        NavigationLink(value: LibraryDestination.artists) { countRow("Artists", systemImage: "music.mic", count: libraryStore.artists.count) }
                    }

                    Section {
                        Button("Rescan Library", systemImage: "arrow.clockwise") {
                            Task { await libraryStore.rescan() }
                        }
                        .disabled(libraryStore.isLoading)
                        Button("Change Music Folder", systemImage: "folder.badge.gearshape") {
                            isFolderImporterPresented = true
                        }
                        .disabled(libraryStore.isLoading)
                    }
                } else {
                    Button("Select Music Folder", systemImage: "folder.badge.plus") {
                        isFolderImporterPresented = true
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .songs: SongsView(tracks: libraryStore.tracks)
                case .albums: AlbumsView(albums: libraryStore.albums)
                case .artists: ArtistsView(artists: libraryStore.artists)
                }
            }
            .fileImporter(isPresented: $isFolderImporterPresented, allowedContentTypes: [.folder]) { result in
                if case let .success(url) = result {
                    Task { await libraryStore.selectFolder(url) }
                }
                // Cancellation intentionally leaves the current library unchanged.
            }
            .alert("Music Library Error", isPresented: errorIsPresented) {
                Button("OK") { libraryStore.dismissError() }
            } message: {
                Text(libraryStore.errorMessage ?? "An unknown error occurred.")
            }
            .task { await libraryStore.restoreAndLoadIfNeeded() }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { libraryStore.errorMessage != nil },
            set: { if !$0 { libraryStore.dismissError() } }
        )
    }

    private func countRow(_ title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(count, format: .number).foregroundStyle(.secondary)
        }
    }
}

private enum LibraryDestination: Hashable {
    case songs, albums, artists
}
