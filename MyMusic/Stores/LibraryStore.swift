import Observation

@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var isLoading = false
    private let service: MusicLibraryServicing

    init(service: MusicLibraryServicing = MusicLibraryService()) { self.service = service }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let library = try? await service.loadLibrary() else { return }
        tracks = library.tracks; albums = library.albums; artists = library.artists
    }
}
