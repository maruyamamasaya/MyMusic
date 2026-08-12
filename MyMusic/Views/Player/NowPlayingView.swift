import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var isQueuePresented = false
    @State private var isEqualizerPresented = false
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
            .onChange(of: playerStore.currentTrack?.id) { _, _ in
                showsAudioDetails = false
            }
        }
    }

    private var nowPlayingContent: some View {
        VStack(spacing: 18) {
            ArtworkAudioDetailsView(
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
                HStack(spacing: 28) {
                    preferenceButton(
                        systemImage: "hand.thumbsdown",
                        accessibilityLabel: "再生頻度を減らす",
                        track: track,
                        isIncrease: false
                    )
                    preferenceButton(
                        systemImage: "hand.thumbsup",
                        accessibilityLabel: "再生頻度を増やす",
                        track: track,
                        isIncrease: true
                    )
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

        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
    }

    private var trackInformation: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(playerStore.currentTrack?.title ?? "Not Playing")
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(playerStore.currentTrack?.artistName ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let track = playerStore.currentTrack {
                    Text("再生回数 \(playbackHistoryStore.playCount(for: track.id))回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let track = playerStore.currentTrack {
                Button {
                    playbackHistoryStore.toggleFavorite(trackID: track.id)
                } label: {
                    Image(systemName: playbackHistoryStore.isFavorite(trackID: track.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .accessibilityLabel(playbackHistoryStore.isFavorite(trackID: track.id) ? "Remove from Favorites" : "Add to Favorites")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preferenceButton(
        systemImage: String,
        accessibilityLabel: String,
        track: Track,
        isIncrease: Bool
    ) -> some View {
        let preference = playbackHistoryStore.playbackPreference(for: track.id)
        let isActive = isIncrease ? preference > 0 : preference < 0

        return Button {
            if isIncrease {
                playbackHistoryStore.increasePlaybackPreference(for: track.id)
            } else {
                playbackHistoryStore.decreasePlaybackPreference(for: track.id)
            }
        } label: {
            Label(accessibilityLabel, systemImage: isActive ? "\(systemImage).fill" : systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 42, height: 36)
                .foregroundStyle(
                    isActive
                        ? LinearGradient(
                            colors: isIncrease ? [.cyan, .blue] : [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [.secondary, .secondary], startPoint: .top, endPoint: .bottom)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ArtworkAudioDetailsView: View {
    let artworkIdentifier: String?
    let trackTitle: String?
    let information: AudioInformation
    let spectrumLevels: [Float]
    @Binding var showsAudioDetails: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { showsAudioDetails.toggle() }
        } label: {
            ZStack {
                if showsAudioDetails {
                    AudioInformationView(information: information, spectrumLevels: spectrumLevels)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    AlbumArtworkView(
                        artworkIdentifier: artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsAudioDetails ? "Audio details" : "Artwork for \(trackTitle ?? "current track")")
        .accessibilityHint(showsAudioDetails ? "Double tap to show artwork" : "Double tap to show audio details")
    }
}

private struct AudioInformationView: View {
    let information: AudioInformation
    let spectrumLevels: [Float]

    private var hasDetails: Bool {
        information.codec != "Unknown" || information.bitRate != nil || information.sampleRate != nil ||
        information.bitDepth != nil || information.channels != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio Details", systemImage: "waveform")
                .font(.headline)

            WaveformView(levels: spectrumLevels)
                .frame(height: 72)
                .accessibilityHidden(true)

            if hasDetails {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    if information.codec != "Unknown" { row("Format / Codec", information.codec) }
                    if let bitRate = information.bitRate { row("Bitrate", "\(bitRate / 1_000) kbps") }
                    if let sampleRate = information.sampleRate { row("Sample Rate", rate(sampleRate)) }
                    if let bitDepth = information.bitDepth { row("Bit Depth", "\(bitDepth) bit") }
                    if let channels = information.channels { row("Channels", channelDescription(channels)) }
                }
                .font(.subheadline)
            } else {
                ContentUnavailableView("No Audio Details", systemImage: "waveform.slash")
            }

            Spacer(minLength: 0)
            Text("Tap to show artwork")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func rate(_ value: Double) -> String {
        String(format: "%.1f kHz", value / 1_000)
    }

    private func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1: "Mono"
        case 2: "Stereo"
        default: "\(channels) ch"
        }
    }
}

private struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let width = max((proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 1)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: width,
                            height: max(3, proxy.size.height * CGFloat(levels[index]))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }
}
