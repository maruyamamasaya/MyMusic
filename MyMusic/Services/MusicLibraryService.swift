import Foundation

protocol MusicLibraryServicing: AnyObject {
    func loadLibrary() async throws -> (tracks: [Track], albums: [Album], artists: [Artist])
}

final class MusicLibraryService: MusicLibraryServicing {
    func loadLibrary() async throws -> (tracks: [Track], albums: [Album], artists: [Artist]) {
        ([], [], [])
    }
}
