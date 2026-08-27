import SwiftUI

struct WorkSizeNowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isQueuePresented = false
    @State private var isEqualizerPresented = false
    @State private var isAddToPlaylistPresented = false
    @State private var showsTrackNavigation = false
    @State private var isScreenDimmed = false
    @State private var dimmingActivityID = UUID()

    private let screenDimmingDelay: Duration = .seconds(5)

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                nowPlayingContent

                ScrollView {
                    nowPlayingContent
                }
            }
            .navigationTitle("作業用再生中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .accessibilityLabel("再生画面を閉じる")
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
            .sheet(isPresented: $isAddToPlaylistPresented) {
                if let track = playerStore.currentTrack { AddToPlaylistSheet(track: track) }
            }
            .onChange(of: playerStore.currentTrack?.id) { _, _ in
                showsTrackNavigation = false
            }
        }
        .overlay {
            if isScreenDimmed {
                screenDimmingOverlay
                    .transition(.opacity)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in registerUserActivity() }
        )
        .task(id: dimmingActivityID) {
            guard scenePhase == .active else { return }
            do {
                try await Task.sleep(for: screenDimmingDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.8)) {
                isScreenDimmed = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                registerUserActivity()
            } else {
                isScreenDimmed = false
                dimmingActivityID = UUID()
            }
        }
    }

    private var screenDimmingOverlay: some View {
        Color.black
            .opacity(0.94)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in registerUserActivity() }
            )
            .accessibilityElement()
            .accessibilityLabel("画面を表示")
            .accessibilityHint("操作すると作業用再生画面の明るさが戻ります")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { registerUserActivity() }
    }

    private func registerUserActivity() {
        if isScreenDimmed {
            withAnimation(.easeOut(duration: 0.2)) {
                isScreenDimmed = false
            }
        }
        dimmingActivityID = UUID()
    }

    private var nowPlayingContent: some View {
        VStack(spacing: 18) {
            WorkSizeArtworkView(
                track: playerStore.currentTrack,
                information: playerStore.audioInformation,
                spectrumLevels: playerStore.spectrumLevels,
                artworkIdentifier: playerStore.currentTrack?.artworkIdentifier,
                trackTitle: playerStore.currentTrack?.title,
                showsTrackNavigation: $showsTrackNavigation,
                canGoPrevious: playerStore.hasPrevious,
                canGoNext: playerStore.hasNext,
                onPrevious: playerStore.previous,
                onNext: playerStore.next
            )
            .containerRelativeFrame(.horizontal) { availableWidth, _ in
                min(availableWidth, 360)
            }

            trackInformation

            if let track = playerStore.currentTrack {
                HStack(spacing: 18) {
                    PlaybackPreferenceButton(track: track, direction: .decrease)
                    PlaybackPreferenceButton(track: track, direction: .increase)
                    BoredomButton(track: track)
                    Button {
                        isAddToPlaylistPresented = true
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .font(.title3)
                            .frame(width: 42, height: 36)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("プレイリストに追加")
                    Button {
                        isQueuePresented = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .frame(width: 42, height: 36)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("再生キューを表示")

                    Button {
                        isEqualizerPresented = true
                    } label: {
                        Image(systemName: "slider.vertical.3")
                            .font(.title3)
                            .frame(width: 42, height: 36)
                            .foregroundStyle(settingsStore.equalizer.isEnabled ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("イコライザ設定を表示")
                    .accessibilityValue(settingsStore.equalizer.isEnabled ? "オン" : "オフ")
                }
            }

            Spacer(minLength: 8)

            ProgressBarView(
                currentTime: playerStore.currentTime,
                duration: playerStore.duration,
                onSeek: playerStore.seek
            )

            WorkSizePlaybackControlsView(
                isPlaying: playerStore.isPlaying,
                isLoading: playerStore.isLoading,
                isShuffleEnabled: playerStore.isShuffleEnabled,
                repeatMode: playerStore.repeatMode,
                onSeekBy: playerStore.skip,
                duration: playerStore.duration,
                onPlayPause: playerStore.togglePlayPause,
                onShuffle: playerStore.toggleShuffle,
                onRepeat: playerStore.cycleRepeatMode
            )
            .padding(.top, -15)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 39)
        .frame(maxHeight: .infinity)
    }

    private var trackInformation: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    text: playerStore.currentTrack?.title ?? "未再生",
                    font: .title2.bold(),
                    lineHeight: 30
                )
                if let artist = currentArtist {
                    NavigationLink {
                        ArtistDetailView(artist: artist)
                    } label: {
                        MarqueeText(text: artist.name, font: .body, lineHeight: 22)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("アーティストページを表示")
                } else {
                    MarqueeText(
                        text: playerStore.currentTrack?.artistName ?? "",
                        font: .body,
                        lineHeight: 22
                    )
                    .foregroundStyle(.secondary)
                }
                if let album = currentAlbum {
                    NavigationLink {
                        AlbumDetailView(album: album)
                    } label: {
                        MarqueeText(text: album.title, font: .caption, lineHeight: 18)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("アルバム、\(album.title)")
                    .accessibilityHint("アルバムページを表示")
                } else if let albumTitle = playerStore.currentTrack?.albumTitle,
                          !albumTitle.isEmpty {
                    MarqueeText(text: albumTitle, font: .caption, lineHeight: 18)
                        .foregroundStyle(.secondary)
                }
                if let track = playerStore.currentTrack {
                    Text("再生回数 \(playbackHistoryStore.playCount(for: track.id))回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let track = playerStore.currentTrack {
                TrackFavoriteButton(track: track, font: .title2, width: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentAlbum: Album? {
        guard let trackID = playerStore.currentTrack?.id else { return nil }
        return libraryStore.albums.first { $0.trackIDs.contains(trackID) }
    }

    private var currentArtist: Artist? {
        guard let trackID = playerStore.currentTrack?.id else { return nil }
        return libraryStore.artists.first { $0.trackIDs.contains(trackID) }
    }
}

private struct WorkSizeArtworkView: View {
    let track: Track?
    let information: AudioInformation
    let spectrumLevels: [Float]
    let artworkIdentifier: String?
    let trackTitle: String?
    @Binding var showsTrackNavigation: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    @State private var showsAudioDetails = false

    var body: some View {
        Group {
            if showsAudioDetails {
                AudioInformationView(
                    track: track,
                    information: information,
                    spectrumLevels: spectrumLevels
                ) {
                    withAnimation(.snappy) {
                        showsAudioDetails = false
                        showsTrackNavigation = false
                    }
                }
            } else {
                navigationArtwork
                    .overlay(alignment: .bottom) {
                        if showsTrackNavigation {
                            Button("オーディオ情報", systemImage: "info.circle") {
                                withAnimation(.snappy) { showsAudioDetails = true }
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderedProminent)
                            .tint(.black.opacity(0.65))
                            .padding()
                        }
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: track?.id) { _, _ in
            showsAudioDetails = false
        }
    }

    private var navigationArtwork: some View {
        ZStack {
            AlbumArtworkView(
                artworkIdentifier: artworkIdentifier,
                displayMode: .fitWithBlurredBackground
            )

            if showsTrackNavigation {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.36))
                    .transition(.opacity)

                HStack(spacing: 54) {
                    trackButton(
                        title: "前の曲",
                        systemImage: "backward.end.fill",
                        isEnabled: canGoPrevious,
                        action: onPrevious
                    )
                    trackButton(
                        title: "次の曲",
                        systemImage: "forward.end.fill",
                        isEnabled: canGoNext,
                        action: onNext
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.snappy) { showsTrackNavigation.toggle() }
        }
        .accessibilityElement(children: showsTrackNavigation ? .contain : .ignore)
        .accessibilityLabel("\(trackTitle ?? "現在の曲")のアートワーク")
        .accessibilityHint(showsTrackNavigation ? "曲送り操作を表示中" : "ダブルタップして前後の曲を表示")
        .accessibilityAction {
            withAnimation(.snappy) { showsTrackNavigation.toggle() }
        }
    }

    private func trackButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 30))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(.black.opacity(0.42), in: Circle())
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct WorkSizePlaybackControlsView: View {
    let isPlaying: Bool
    let isLoading: Bool
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let onSeekBy: (TimeInterval) -> Void
    let duration: TimeInterval
    let onPlayPause: () -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button("シャッフル", systemImage: "shuffle", action: onShuffle)
                .foregroundStyle(isShuffleEnabled ? Color.accentColor : Color.secondary)
                .accessibilityValue(isShuffleEnabled ? "On" : "Off")
                .frame(minWidth: 42, minHeight: 44)

            seekButton(title: "1分戻る", systemImage: "gobackward", offset: -60, caption: "1分")
            seekButton(title: "10秒戻る", systemImage: "gobackward.10", offset: -10)

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 62, height: 62)
                    .accessibilityLabel("オーディオを読み込み中")
            } else {
                Button(
                    isPlaying ? "一時停止" : "再生",
                    systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill",
                    action: onPlayPause
                )
                .font(.system(size: 62))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isPlaying ? "一時停止" : "再生")
            }

            seekButton(title: "10秒進む", systemImage: "goforward.10", offset: 10)
            seekButton(title: "1分進む", systemImage: "goforward", offset: 60, caption: "1分")

            Button(repeatLabel, systemImage: repeatSymbol, action: onRepeat)
                .foregroundStyle(repeatMode == .off ? Color.secondary : Color.accentColor)
                .accessibilityValue(repeatLabel)
                .frame(minWidth: 42, minHeight: 44)
        }
        .font(.system(size: 19))
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func seekButton(
        title: String,
        systemImage: String,
        offset: TimeInterval,
        caption: String? = nil
    ) -> some View {
        Button {
            onSeekBy(offset)
        } label: {
            if let caption {
                ZStack {
                    Image(systemName: systemImage)
                    Text(caption)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
            } else {
                Image(systemName: systemImage)
            }
        }
        .frame(minWidth: 42, minHeight: 44)
        .disabled(isLoading || duration <= 0)
        .accessibilityLabel(title)
    }

    private var repeatSymbol: String {
        repeatMode == .one ? "repeat.1" : "repeat"
    }

    private var repeatLabel: String {
        switch repeatMode {
        case .off: "Repeat Off"
        case .all: "Repeat All"
        case .one: "Repeat One"
        }
    }
}
