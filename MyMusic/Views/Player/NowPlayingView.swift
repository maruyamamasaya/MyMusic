import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var isQueuePresented = false
    @State private var isEqualizerPresented = false
    @State private var isAddToPlaylistPresented = false
    @State private var showsAudioDetails = false

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                nowPlayingContent

                ScrollView {
                    nowPlayingContent
                }
            }
            .navigationTitle("再生中")
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
                showsAudioDetails = false
            }
        }
    }

    private var nowPlayingContent: some View {
        VStack(spacing: 18) {
            ArtworkAudioDetailsView(
                track: playerStore.currentTrack,
                artworkIdentifier: playerStore.currentTrack?.artworkIdentifier,
                trackTitle: playerStore.currentTrack?.title,
                information: playerStore.audioInformation,
                spectrumLevels: playerStore.spectrumLevels,
                showsAudioDetails: $showsAudioDetails
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

            PlaybackControlsView(
                isPlaying: playerStore.isPlaying,
                isLoading: playerStore.isLoading,
                isShuffleEnabled: playerStore.isShuffleEnabled,
                repeatMode: playerStore.repeatMode,
                canGoPrevious: playerStore.hasPrevious,
                canGoNext: playerStore.hasNext,
                onPrevious: playerStore.previous,
                onPlayPause: playerStore.togglePlayPause,
                onNext: playerStore.next,
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

private struct ArtworkAudioDetailsView: View {
    let track: Track?
    let artworkIdentifier: String?
    let trackTitle: String?
    let information: AudioInformation
    let spectrumLevels: [Float]
    @Binding var showsAudioDetails: Bool

    var body: some View {
        ZStack {
            if showsAudioDetails {
                AudioInformationView(
                    track: track,
                    information: information,
                    spectrumLevels: spectrumLevels
                ) {
                    withAnimation(.snappy) { showsAudioDetails = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Button {
                    withAnimation(.snappy) { showsAudioDetails = true }
                } label: {
                    AlbumArtworkView(
                        artworkIdentifier: artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trackTitle ?? "現在の曲")のアートワーク")
                .accessibilityHint("ダブルタップしてオーディオ情報を表示")
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
