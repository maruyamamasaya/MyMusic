import Foundation
import Observation

@MainActor
@Observable
final class FavoriteStore {
    private(set) var favorites = LibraryFavorites()
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let persistence: FavoritePersistenceServicing
    private var saveTask: Task<Void, Never>?
    private var isLoading = false

    init(persistence: FavoritePersistenceServicing? = nil) {
        self.persistence = persistence ?? FavoritePersistenceService()
    }

    func loadIfNeeded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false; isLoaded = true }
        do {
            let loaded = try await persistence.load()
            favorites.albumIDs.formUnion(loaded.albumIDs)
            favorites.artistIDs.formUnion(loaded.artistIDs)
        } catch {
            errorMessage = "お気に入りを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func isFavorite(albumID: Album.ID) -> Bool { favorites.albumIDs.contains(albumID) }
    func isFavorite(artistID: Artist.ID) -> Bool { favorites.artistIDs.contains(artistID) }

    func toggleFavorite(albumID: Album.ID) {
        if favorites.albumIDs.remove(albumID) == nil { favorites.albumIDs.insert(albumID) }
        persist()
    }

    func toggleFavorite(artistID: Artist.ID) {
        if favorites.artistIDs.remove(artistID) == nil { favorites.artistIDs.insert(artistID) }
        persist()
    }

    func favoriteAlbums(from albums: [Album], limit: Int? = nil) -> [Album] {
        limited(albums.filter { favorites.albumIDs.contains($0.id) }, to: limit)
    }

    func favoriteArtists(from artists: [Artist], limit: Int? = nil) -> [Artist] {
        limited(artists.filter { favorites.artistIDs.contains($0.id) }, to: limit)
    }

    func randomFavoriteAlbums(from albums: [Album], limit: Int) -> [Album] {
        Array(favoriteAlbums(from: albums).shuffled().prefix(limit))
    }

    func randomFavoriteArtists(from artists: [Artist], limit: Int) -> [Artist] {
        Array(favoriteArtists(from: artists).shuffled().prefix(limit))
    }

    func dismissError() { errorMessage = nil }

    private func limited<Element>(_ values: [Element], to limit: Int?) -> [Element] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }

    private func persist() {
        let snapshot = favorites
        saveTask?.cancel()
        saveTask = Task { [weak self, persistence] in
            do {
                try await persistence.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = "お気に入りを保存できませんでした: \(error.localizedDescription)"
            }
        }
    }
}
