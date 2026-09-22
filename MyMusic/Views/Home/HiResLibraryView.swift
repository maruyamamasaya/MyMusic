import SwiftUI

private enum HiResLibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case songs
    case albums
    case artists

    var id: Self { self }

    var title: String {
        switch self {
        case .songs: "曲名"
        case .albums: "アルバム"
        case .artists: "アーティスト"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .albums: "square.stack"
        case .artists: "music.mic"
        }
    }
}

struct HiResLibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @State private var outputStore = HiResDirectOutputProbeStore()

    private var catalog: HiResLibraryCatalog { libraryStore.hiResLibraryCatalog }

    var body: some View {
        List {
            Section {
                ForEach(HiResLibraryCategory.allCases) { category in
                    NavigationLink(value: category) {
                        Label {
                            HStack {
                                Text(category.title)
                                Spacer()
                                Text("\(count(for: category))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: category.systemImage)
                        }
                    }
                }
            } header: {
                Text("ハイレゾ専用ライブラリ")
            } footer: {
                Text("ジャンルが「ハイレゾ」の曲、またはCD品質を超えるロスレス音源を通常ライブラリから分離して表示します。")
            }

            ratePreparationSection
            outputStatusSection
        }
        .themeScreen()
        .navigationTitle("ハイレゾ音源")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: HiResLibraryCategory.self) { category in
            destination(for: category)
        }
        .onDisappear { outputStore.stop() }
    }

    private func count(for category: HiResLibraryCategory) -> Int {
        switch category {
        case .songs: catalog.tracks.count
        case .albums: catalog.albums.count
        case .artists: catalog.artists.count
        }
    }

    @ViewBuilder
    private func destination(for category: HiResLibraryCategory) -> some View {
        switch category {
        case .songs:
            HiResTrackCollectionView(title: "曲名", tracks: catalog.tracks, outputStore: outputStore)
        case .albums:
            HiResAlbumListView(catalog: catalog, outputStore: outputStore)
        case .artists:
            HiResArtistListView(catalog: catalog, outputStore: outputStore)
        }
    }

    private var ratePreparationSection: some View {
        Section("内蔵PCMで出力レート準備") {
            ForEach([44_100.0, 48_000, 88_200, 96_000, 192_000], id: \.self) { sampleRate in
                Button {
                    playerStore.stop()
                    outputStore.prepare(sampleRate: sampleRate)
                } label: {
                    LabeledContent(String(format: "%.1f kHz", sampleRate / 1_000)) {
                        Image(systemName: "waveform")
                    }
                }
                .disabled(outputStore.hasActiveSession || outputStore.state == .switching)
            }
        }
    }

    @ViewBuilder
    private var outputStatusSection: some View {
        if let snapshot = outputStore.snapshot {
            Section("出力診断") {
                LabeledContent("音源レート", value: rate(snapshot.sourceSampleRate))
                LabeledContent("出力先", value: snapshot.outputName)
                LabeledContent("Audio Session", value: rate(snapshot.sessionSampleRate))
                LabeledContent("Audio Queue", value: rate(snapshot.queueHardwareSampleRate))
                if outputStore.hasActiveSession {
                    Button("停止", role: .destructive) { outputStore.stop() }
                }
            }
        }
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "—" }
        return String(format: "%.1f kHz", value / 1_000)
    }
}

private struct HiResAlbumListView: View {
    let catalog: HiResLibraryCatalog
    let outputStore: HiResDirectOutputProbeStore

    var body: some View {
        List(catalog.albums) { album in
            NavigationLink {
                HiResTrackCollectionView(
                    title: album.title,
                    tracks: catalog.tracks(for: album.trackIDs),
                    outputStore: outputStore
                )
            } label: {
                Label(album.title, systemImage: "square.stack")
            }
        }
        .themeScreen()
        .navigationTitle("アルバム")
    }
}

private struct HiResArtistListView: View {
    let catalog: HiResLibraryCatalog
    let outputStore: HiResDirectOutputProbeStore

    var body: some View {
        List(catalog.artists) { artist in
            NavigationLink {
                HiResTrackCollectionView(
                    title: artist.name,
                    tracks: catalog.tracks(for: artist.trackIDs),
                    outputStore: outputStore
                )
            } label: {
                Label(artist.name, systemImage: "music.mic")
            }
        }
        .themeScreen()
        .navigationTitle("アーティスト")
    }
}

private struct HiResTrackCollectionView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var query = ""

    let title: String
    let tracks: [Track]
    let outputStore: HiResDirectOutputProbeStore

    private var filteredTracks: [Track] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedStandardContains(query)
                || $0.artistName.localizedStandardContains(query)
                || ($0.albumTitle?.localizedStandardContains(query) == true)
        }
    }

    var body: some View {
        List {
            if let snapshot = outputStore.snapshot {
                Section("出力") {
                    LabeledContent("音源", value: String(format: "%.1f kHz", snapshot.sourceSampleRate / 1_000))
                    LabeledContent("Audio Queue", value: snapshot.queueHardwareSampleRate.map { String(format: "%.1f kHz", $0 / 1_000) } ?? "—")
                    if outputStore.hasActiveSession {
                        Button("停止", role: .destructive) { outputStore.stop() }
                    }
                }
            }

            Section("曲") {
                if filteredTracks.isEmpty {
                    ContentUnavailableView("ハイレゾ音源はありません", systemImage: "waveform")
                } else {
                    ForEach(filteredTracks) { track in
                        PlayableTrackRowView(track: track) {
                            playerStore.stop()
                            outputStore.stop()
                            outputStore.play(track: track, historyStore: playbackHistoryStore)
                        }
                    }
                }
            }
        }
        .themeScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "曲名、アーティスト、アルバムを検索")
    }
}
