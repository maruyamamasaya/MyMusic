import SwiftUI

struct HighlightPlayerView: View {
    @Environment(HighlightPlayerStore.self) private var highlightStore
    @Environment(LibraryStore.self) private var libraryStore
    @State private var visibleTrackID: Track.ID?
    @State private var playlistTrack: Track?
    @State private var informationTrack: Track?
    @State private var isQueuePresented = false
    @State private var isEqualizerPresented = false

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
        .task(id: libraryStore.tracks.map(\.id)) {
            highlightStore.updateLibrary(libraryStore.tracks)
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
        .sheet(item: $playlistTrack, onDismiss: highlightStore.endPlaylistInteraction) { track in
            AddToPlaylistSheet(track: track)
        }
        .sheet(item: $informationTrack) { track in
            HighlightTrackInformationView(track: track) {
                highlightStore.prepareFullPlayback()
                onPresentNowPlaying()
            }
        }
        .sheet(isPresented: $isQueuePresented) {
            QueueView()
        }
        .sheet(isPresented: $isEqualizerPresented) {
            NavigationStack {
                EqualizerSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { isEqualizerPresented = false }
                        }
                    }
            }
        }
    }

    private var highlightFeed: some View {
        GeometryReader { viewport in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(highlightStore.queue) { track in
                        HighlightTrackPage(
                            track: track,
                            candidate: highlightStore.candidate(for: track),
                            isCurrent: track.id == highlightStore.currentTrack?.id,
                            isAnalyzing: track.id == highlightStore.currentTrack?.id && highlightStore.isAnalyzingCurrentTrack,
                            isHighlightPlaybackActive: highlightStore.isHighlightPlaybackActive,
                            candidateNumber: highlightStore.currentCandidateNumber,
                            candidateCount: highlightStore.currentCandidateCount,
                            onReshuffle: highlightStore.reshuffle,
                            onAnotherPart: highlightStore.playAnotherPart,
                            onAddToPlaylist: {
                                highlightStore.beginPlaylistInteraction()
                                playlistTrack = track
                            },
                            onShowInformation: { informationTrack = track },
                            onShowQueue: { isQueuePresented = true },
                            onShowEqualizer: { isEqualizerPresented = true },
                            onFullPlayback: {
                                highlightStore.prepareFullPlayback()
                                onPresentNowPlaying()
                            },
                            onResumeHighlight: highlightStore.resumeHighlightPlayback
                        )
                        .frame(width: viewport.size.width, height: viewport.size.height)
                        .id(track.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $visibleTrackID, anchor: .top)
        }
        .clipped()
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
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @Environment(SettingsStore.self) private var settingsStore

    let track: Track
    let candidate: HighlightCandidate
    let isCurrent: Bool
    let isAnalyzing: Bool
    let isHighlightPlaybackActive: Bool
    let candidateNumber: Int
    let candidateCount: Int
    let onReshuffle: () -> Void
    let onAnotherPart: () -> Void
    let onAddToPlaylist: () -> Void
    let onShowInformation: () -> Void
    let onShowQueue: () -> Void
    let onShowEqualizer: () -> Void
    let onFullPlayback: () -> Void
    let onResumeHighlight: () -> Void

    private var isFavorite: Bool { preferenceStore.isFavorite(trackID: track.id) }

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

                    Button(action: togglePlaybackFromArtwork) {
                        AlbumArtworkView(
                            artworkIdentifier: track.artworkIdentifier,
                            displayMode: .fitWithBlurredBackground
                        )
                        .frame(width: artworkSize(in: proxy.size), height: artworkSize(in: proxy.size))
                        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCurrent || playerStore.isLoading)
                    .accessibilityLabel(playerStore.isPlaying ? "一時停止" : "再生")
                    .accessibilityHint("ジャケットをタップして再生状態を切り替えます")

                    trackDetails
                    actionBar
                    playbackButtons
                    progressBar
                }
                .padding(.horizontal, 20)
                .padding(.top, max(proxy.safeAreaInsets.top, 16) + 12)
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
                preferenceStore.toggleFavorite(trackID: track.id)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? .pink : .white)
            }
            .accessibilityLabel(isFavorite ? "お気に入りから削除" : "お気に入りに追加")

            Button {
                preferenceStore.increasePlaybackPreference(for: track.id)
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .foregroundStyle(playbackPreference > 0 ? .green : .white)
            }
            .accessibilityLabel("グッド")
            .accessibilityValue("評価 \(playbackPreference)")

            Button {
                preferenceStore.decreasePlaybackPreference(for: track.id)
            } label: {
                Image(systemName: "hand.thumbsdown.fill")
                    .foregroundStyle(playbackPreference < 0 ? .orange : .white)
            }
            .accessibilityLabel("よくないね")
            .accessibilityValue("評価 \(playbackPreference)")

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
        HStack(spacing: 8) {
            Button("フルで再生", systemImage: "music.note", action: onFullPlayback)
                .buttonStyle(HighlightCapsuleButtonStyle())

            Spacer()

            Button("再生キュー", systemImage: "list.bullet", action: onShowQueue)
                .labelStyle(.iconOnly)
                .buttonStyle(HighlightCircleButtonStyle())
                .accessibilityLabel("再生キューを表示")

            Button(action: onShowEqualizer) {
                Image(systemName: "slider.vertical.3")
                    .foregroundStyle(settingsStore.equalizer.isEnabled ? Color.cyan : Color.white)
            }
                .buttonStyle(HighlightCircleButtonStyle())
                .accessibilityLabel("イコライザ設定を表示")
                .accessibilityValue(settingsStore.equalizer.isEnabled ? "オン" : "オフ")

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

    private var playbackPreference: Int {
        preferenceStore.playbackPreference(for: track.id)
    }

    private func togglePlaybackFromArtwork() {
        guard isCurrent, !playerStore.isLoading else { return }
        if isHighlightPlaybackActive {
            playerStore.togglePlayPause()
        } else {
            onResumeHighlight()
        }
    }

    private func artworkSize(in size: CGSize) -> CGFloat {
        min(max(size.width - 44, 180), size.height * 0.46, 440)
    }
}

private struct HighlightTrackInformationView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
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
                        preferenceStore.isFavorite(trackID: track.id) ? "お気に入りから削除" : "お気に入りに追加",
                        systemImage: preferenceStore.isFavorite(trackID: track.id) ? "heart.slash" : "heart"
                    ) {
                        preferenceStore.toggleFavorite(trackID: track.id)
                    }
                    Menu("プレイリストに追加", systemImage: "text.badge.plus") {
                        ForEach(playlistStore.playlists(compatibleWith: track)) { playlist in
                            Button(playlist.name) { playlistStore.addTrack(track, to: playlist.id) }
                        }
                    }
                }

                Section {
                    Button("曲の最初からフルで再生", systemImage: "play.fill") {
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
