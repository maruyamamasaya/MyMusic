import Foundation

struct LibraryFavorites: Codable, Sendable {
    var albumIDs: Set<Album.ID> = []
    var artistIDs: Set<Artist.ID> = []
}
