import SwiftUI

struct HighlightPlayerView: View {
    @Environment(HighlightPlayerStore.self) private var highlightStore
    @Environment(LibraryStore.self) private var libraryStore
    @State private var visibleTrackID: Track.ID?
    @State private var playlistTrack: Track?
    @State private var informationTrack: Track?

    let onPresentNowPlaying: () -> Void

    var body: some View {
        Group {
            if highlightStore.queue.isEmpty {
                emptyState
            } else {
                highlightFeed
            }
        }
        .background(Color.black)
        .task(id: libraryStore.unfilteredTracks.map(\.id)) {
            highlightStore.updateLibrary(libraryStore.unfilteredTracks)
            highlightStore.startIfNeeded()
            visibleTrackID = highlightStore.currentTrack?.id
        }
        .onChange(of: highlightStore.currentTrack?.id) { _, newTrackID in
            guard visibleTrackID != newTrackID else { return }
            withAnimation(.snappy(duration: 0.32)) { visibleTrackID = newTrackID }
        }
        .onChange(of: visibleTrackID) { _, newTrackID in
            guard let newTrackID, newTrackID != highlightStore.currentTrack?.id else { return }
            highlightStore.move(to: newTrackID)
        }
        .sheet(item: $playlistTrack) { track in
            AddToPlaylistSheet(track: track)
        }
        .sheet(item: $informationTrack) { track in
            HighlightTrackInformationView(track: track) {
                highlightStore.prepareFullPlayback()
                onPresentNowPlaying()
            }
        }
    }

    private var highlightFeed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(highlightStore.queue) { track in
                    HighlightTrackPage(
                        track: track,
                        candidate: highlightStore.candidate(for: track),
                        isCurrent: track.id == highlightStore.currentTrack?.id,
                        isAnalyzing: track.id == highlightStore.currentTrack?.id && highlightStore.isAnalyzingCurrentTrack,
                        isHighlightPlaybackActive: highlightStore.isHighlightPlaybackActive,
                        selectedGenre: highlightStore.selectedGenre,
                        availableGenres: highlightStore.availableGenres,
                        candidateNumber: highlightStore.currentCandidateNumber,
                        candidateCount: highlightStore.currentCandidateCount,
                        onSelectGenre: highlightStore.selectGenre,
                        onReshuffle: highlightStore.reshuffle,
                        onAnotherPart: highlightStore.playAnotherPart,
                        onAddToPlaylist: { playlistTrack = track },
                        onShowInformation: { informationTrack = track },
                        onFullPlayback: {
                            highlightStore.prepareFullPlayback()
                            onPresentNowPlaying()
                        },
                        onResumeHighlight: highlightStore.resumeHighlightPlayback
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(track.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleTrackID)
        .ignoresSafeArea(edges: .top)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                libraryStore.isLoading ? "ライブラリを読み込み中" : "再生できる曲がありません",
                systemImage: libraryStore.isLoading ? "waveform" : "music.note"
            )
        } description: {
            Text(libraryStore.isLoading
                 ? "ハイライトの準備をしています。"
                 : "ライブラリへ曲を追加すると、ここからハイライト再生を始められます。")
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HighlightTrackPage: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var historyStore

    let track: Track
    let candidate: HighlightCandidate
    let isCurrent: Bool
    let isAnalyzing: Bool
    let isHighlightPlaybackActive: Bool
    let selectedGenre: String?
    let availableGenres: [String]
    let candidateNumber: Int
    let candidateCount: Int
    let onSelectGenre: (String?) -> Void
    let onReshuffle: () -> Void
    let onAnotherPart: () -> Void
    let onAddToPlaylist: () -> Void
    let onShowInformation: () -> Void
    let onFullPlayback: () -> Void
    let onResumeHighlight: () -> Void

    private var isFavorite: Bool { historyStore.isFavorite(trackID: track.id) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                AlbumArtworkView(artworkIdentifier: track.artworkIdentifier)
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .scaleEffect(1.35)
                    .blur(radius: 54)
                    .opacity(0.44)

                LinearGradient(
                    colors: [.black.opacity(0.18), .black.opacity(0.12), .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 14) {
                    header

                    Spacer(minLength: 0)

                    AlbumArtworkView(
                        artworkIdentifier: track.artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                    .frame(width: artworkSize(in: proxy.size), height: artworkSize(in: proxy.size))
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 12)

                    trackDetails
                    actionBar
                    playbackButtons
                    progressBar
                }
                .padding(.horizontal, 20)
                .padding(.top, max(proxy.safeAreaInsets.top, 12) + 8)
                .padding(.bottom, 14)
            }
            .clipped()
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ハイライト")
                    .font(.headline)
                Text("上へスワイプして次の曲")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Menu {
                Button("すべて", systemImage: selectedGenre == nil ? "checkmark" : "music.note.list") {
                    onSelectGenre(nil)
                }
                ForEach(availableGenres, id: \.self) { genre in
                    Button(genre, systemImage: selectedGenre == genre ? "checkmark" : "music.note") {
                        onSelectGenre(genre)
                    }
                }
            } label: {
                Label(selectedGenre ?? "すべて", systemImage: "line.3.horizontal.decrease.circle")
                    .lineLimit(1)
            }
            .buttonStyle(HighlightCapsuleButtonStyle())

            Button("シャッフルし直す", systemImage: "shuffle", action: onReshuffle)
                .labelStyle(.iconOnly)
                .buttonStyle(HighlightCircleButtonStyle())
        }
    }

    private var trackDetails: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(track.title)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(track.artistName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
            HStack(spacing: 6) {
                Label(
                    "\(TimeFormatter.string(from: candidate.startTime))–\(TimeFormatter.string(from: candidate.endTime))",
                    systemImage: "waveform"
                )
                if isCurrent, candidateCount > 1 {
                    Text("候補 \(max(candidateNumber, 1))/\(candidateCount)")
                }
                if isAnalyzing {
                    ProgressView().controlSize(.mini).tint(.white)
                    Text("解析中")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                historyStore.toggleFavorite(trackID: track.id)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? .pink : .white)
            }
            .accessibilityLabel(isFavorite ? "お気に入りから削除" : "お気に入りに追加")

            Button("プレイリストに追加", systemImage: "text.badge.plus", action: onAddToPlaylist)
            Button("曲情報", systemImage: "ellipsis", action: onShowInformation)

            Spacer()

            Button("別の部分", systemImage: "waveform.badge.plus", action: onAnotherPart)
                .disabled(!isCurrent || playerStore.isLoading)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(HighlightCircleButtonStyle())
    }

    private var playbackButtons: some View {
        HStack(spacing: 12) {
            Button("フルで再生", systemImage: "music.note", action: onFullPlayback)
                .buttonStyle(HighlightCapsuleButtonStyle())

            Spacer()

            if isCurrent, !isHighlightPlaybackActive {
                Button("ハイライトを再開", systemImage: "sparkles", action: onResumeHighlight)
                    .buttonStyle(HighlightCapsuleButtonStyle(prominent: true))
            } else {
                Button(
                    playerStore.isPlaying ? "一時停止" : "再生",
                    systemImage: playerStore.isPlaying ? "pause.fill" : "play.fill"
                ) {
                    playerStore.togglePlayPause()
                }
                .buttonStyle(HighlightCapsuleButtonStyle(prominent: true))
                .disabled(!isCurrent || playerStore.isLoading)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.24))
                Capsule().fill(.white).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
        .accessibilityLabel("ハイライト再生位置")
        .accessibilityValue("\(Int(progress * 100))パーセント")
    }

    private var progress: Double {
        guard isCurrent, candidate.duration > 0 else { return 0 }
        return min(max((playerStore.currentTime - candidate.startTime) / candidate.duration, 0), 1)
    }

    private func artworkSize(in size: CGSize) -> CGFloat {
        min(max(size.width - 44, 180), size.height * 0.46, 440)
    }
}

private struct HighlightTrackInformationView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss

    let track: Track
    let onFullPlayback: () -> Void

    private var artist: Artist? {
        libraryStore.artists.first { $0.trackIDs.contains(track.id) }
    }

    private var album: Album? {
        libraryStore.albums.first { $0.trackIDs.contains(track.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AlbumArtworkView(
                        artworkIdentifier: track.artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("曲情報") {
                    LabeledContent("曲名", value: track.title)
                    LabeledContent("アーティスト", value: track.artistName)
                    if let albumTitle = track.albumTitle {
                        LabeledContent("アルバム", value: albumTitle)
                    }
                    if let genre = track.genre { LabeledContent("ジャンル", value: genre) }
                    LabeledContent("長さ", value: TimeFormatter.string(from: track.duration))
                }

                Section("ライブラリ") {
                    if let artist {
                        NavigationLink("アーティストを表示") { ArtistDetailView(artist: artist) }
                    }
                    if let album {
                        NavigationLink("アルバムを表示") { AlbumDetailView(album: album) }
                    }
                    Button(
                        historyStore.isFavorite(trackID: track.id) ? "お気に入りから削除" : "お気に入りに追加",
                        systemImage: historyStore.isFavorite(trackID: track.id) ? "heart.slash" : "heart"
                    ) {
                        historyStore.toggleFavorite(trackID: track.id)
                    }
                    Menu("プレイリストに追加", systemImage: "text.badge.plus") {
                        ForEach(playlistStore.playlists) { playlist in
                            Button(playlist.name) { playlistStore.addTrack(track, to: playlist.id) }
                        }
                    }
                }

                Section {
                    Button("現在位置からフルで再生", systemImage: "play.fill") {
                        dismiss()
                        onFullPlayback()
                    }
                }
            }
            .navigationTitle("曲情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

private struct HighlightCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(width: 42, height: 42)
            .background(.ultraThinMaterial, in: Circle())
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct HighlightCapsuleButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(prominent ? Color.white : Color.clear)
            .foregroundStyle(prominent ? Color.black : Color.white)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
