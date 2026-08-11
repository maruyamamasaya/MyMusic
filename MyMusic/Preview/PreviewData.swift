import Foundation

enum PreviewData {
    static let tracks = [
        Track(id: UUID(), title: "Track A", artistName: "Artist A", albumTitle: "Album A", duration: 245, fileURL: URL(fileURLWithPath: "/preview/track-a.flac"), audioFormat: AudioFormat(codec: .flac, bitRate: nil, sampleRate: 96_000, bitDepth: 24, channels: 2)),
        Track(id: UUID(), title: "Track B", artistName: "Artist B", albumTitle: "Album B", duration: 198, fileURL: URL(fileURLWithPath: "/preview/track-b.m4a"), audioFormat: AudioFormat(codec: .aac, bitRate: 256_000, sampleRate: 44_100, bitDepth: nil, channels: 2))
    ]
    static let albums = [
        Album(id: UUID(), title: "Album A", artistName: "Artist A", year: 2026, trackIDs: [tracks[0].id]),
        Album(id: UUID(), title: "Album B", artistName: "Artist B", year: 2025, trackIDs: [tracks[1].id])
    ]
    static let artists = [
        Artist(id: UUID(), name: "Artist A", albumIDs: [albums[0].id], trackIDs: [tracks[0].id]),
        Artist(id: UUID(), name: "Artist B", albumIDs: [albums[1].id], trackIDs: [tracks[1].id])
    ]
}
