import SwiftUI

struct HiResNowPlayingView: View {
    @Environment(\.appTheme) private var appTheme
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    let store: HiResDirectOutputProbeStore

    @State private var showsAudioInformation = false
    @State private var isQueuePresented = false
    @State private var isEqualizerPresented = false

    var body: some View {
        NavigationStack {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .themeScreen()
            .navigationTitle("ハイレゾ再生中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $isQueuePresented) {
                HiResQueueView(store: store)
            }
            .sheet(isPresented: $isEqualizerPresented) {
                HiResEqualizerInformationView()
            }
            .onChange(of: store.currentTrack?.id) { _, _ in
                showsAudioInformation = false
            }
        }
    }

    private var content: some View {
        VStack(spacing: 18) {
            artworkPanel
                .containerRelativeFrame(.horizontal) { availableWidth, _ in
                    min(availableWidth, 360)
                }

            trackInformation
            quickActions

            Spacer(minLength: 8)

            ProgressBarView(
                currentTime: store.currentTime,
                duration: store.duration,
                onSeek: store.seek
            )

            playbackControls
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var artworkPanel: some View {
        ZStack {
            if showsAudioInformation {
                HiResAudioInformationPanel(track: store.currentTrack, snapshot: store.snapshot) {
                    withAnimation(.snappy) { showsAudioInformation = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Button {
                    withAnimation(.snappy) { showsAudioInformation = true }
                } label: {
                    AlbumArtworkView(
                        artworkIdentifier: store.currentTrack?.artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(store.currentTrack?.title ?? "現在の曲")のアートワーク")
                .accessibilityHint("ダブルタップしてオーディオ情報を表示")
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trackInformation: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    text: store.currentTrack?.title ?? "未再生",
                    font: .title2.bold(),
                    lineHeight: 30
                )
                MarqueeText(
                    text: store.currentTrack?.artistName ?? "",
                    font: .body,
                    lineHeight: 22
                )
                .foregroundStyle(.secondary)
                if let album = store.currentTrack?.albumTitle, !album.isEmpty {
                    MarqueeText(text: album, font: .caption, lineHeight: 18)
                        .foregroundStyle(.secondary)
                }
                if let track = store.currentTrack {
                    HStack(spacing: 10) {
                        Text("再生回数 \(playbackHistoryStore.playCount(for: track.id))回")
                        if let rate = store.snapshot?.queueHardwareSampleRate {
                            Text(rateText(rate))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let track = store.currentTrack {
                HStack(spacing: 8) {
                    TrackFavoriteButton(track: track, font: .title2, width: 36)
                    ListenLaterButton(track: track, font: .title2, width: 36)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickActions: some View {
        HStack(spacing: 24) {
            Button {
                isQueuePresented = true
            } label: {
                Label("再生キュー", systemImage: "list.bullet")
            }

            Button {
                isEqualizerPresented = true
            } label: {
                Label("イコライザ", systemImage: "slider.vertical.3")
                    .foregroundStyle(settingsStore.equalizer.isEnabled
                                     ? ThemePalette.resolve(appTheme).accent
                                     : Color.secondary)
            }
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
    }

    private var playbackControls: some View {
        HStack {
            Button("前の曲", systemImage: "backward.end.fill", action: store.previous)
                .font(.system(size: 24))
                .disabled(!store.canGoPrevious || store.isLoading)

            Spacer()

            Button("15秒戻る", systemImage: "gobackward.15") { store.skip(by: -15) }
                .font(.system(size: 22))
                .disabled(store.currentTrack == nil || store.isLoading)

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 62, height: 62)
                    .accessibilityLabel("オーディオを読み込み中")
            } else {
                Button(
                    store.isPlaying ? "一時停止" : "再生",
                    systemImage: store.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                    action: store.togglePlayPause
                )
                .font(.system(size: 62))
                .contentTransition(.symbolEffect(.replace))
            }

            Spacer()

            Button("15秒進む", systemImage: "goforward.15") { store.skip(by: 15) }
                .font(.system(size: 22))
                .disabled(store.currentTrack == nil || store.isLoading)

            Spacer()

            Button("次の曲", systemImage: "forward.end.fill", action: store.next)
                .font(.system(size: 24))
                .disabled(!store.canGoNext || store.isLoading)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func rateText(_ value: Double) -> String {
        String(format: "%.1f kHz", value / 1_000)
    }
}

private struct HiResAudioInformationPanel: View {
    let track: Track?
    let snapshot: HiResAudioQueueProbeSnapshot?
    let onShowArtwork: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onShowArtwork) {
                    HStack {
                        Label("オーディオ情報", systemImage: "waveform")
                            .font(.headline)
                        Spacer()
                        if track?.audioFormat?.isHiResolution == true {
                            Text("Hi-Res")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("ダブルタップしてアートワークに戻る")

                if let track {
                    TrackDetailGridView(
                        title: "音源",
                        items: TrackDetailPresentation.audioItems(for: track)
                    )
                }

                if let snapshot {
                    Divider()
                    TrackDetailGridView(title: "出力", items: outputItems(snapshot))
                }

                if let track {
                    Divider()
                    TrackDetailGridView(
                        title: "曲の詳細",
                        items: TrackDetailPresentation.metadataItems(for: track)
                    )
                }

                Button("アートワークに戻る", action: onShowArtwork)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.025, green: 0.035, blue: 0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(RadialGradient(
                            colors: [.blue.opacity(0.26), .clear],
                            center: .topTrailing,
                            startRadius: 12,
                            endRadius: 300
                        ))
                }
        }
    }

    private func outputItems(_ snapshot: HiResAudioQueueProbeSnapshot) -> [TrackDetailItem] {
        var items = [
            TrackDetailItem(id: "destination", label: "出力先", value: snapshot.outputName),
            TrackDetailItem(id: "connection", label: "接続種別", value: snapshot.outputPortType),
            TrackDetailItem(id: "sessionRate", label: "Audio Session", value: rate(snapshot.sessionSampleRate)),
            TrackDetailItem(id: "queueRate", label: "Audio Queue", value: rate(snapshot.queueHardwareSampleRate))
        ]
        if let outputRate = snapshot.queueHardwareSampleRate {
            let isNative = abs(snapshot.sourceSampleRate - outputRate) < 1
            items.append(TrackDetailItem(
                id: "signalPath",
                label: "信号経路",
                value: isNative ? "ネイティブレート" : "サンプルレート変換あり"
            ))
        }
        return items
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "—" }
        return String(format: "%.1f kHz", value / 1_000)
    }
}

private struct HiResQueueView: View {
    @Environment(\.dismiss) private var dismiss
    let store: HiResDirectOutputProbeStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, track in
                    Button {
                        store.playTrack(at: index)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            AlbumArtworkView(artworkIdentifier: track.artworkIdentifier)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).lineLimit(1)
                                Text(track.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if index == store.currentIndex {
                                Image(systemName: store.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .themeScreen()
            .navigationTitle("ハイレゾ再生キュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

private struct HiResEqualizerInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("USB DACへの直接出力中はイコライザを通りません", systemImage: "waveform.badge.exclamationmark")
                } footer: {
                    Text("通常のイコライザはAVAudioEngine専用です。Audio QueueへEQを挿入するとPCMを加工する別の再生方式になるため、現在のネイティブレート直接出力では適用しません。")
                }

                Section {
                    NavigationLink("通常再生用のイコライザ設定") {
                        EqualizerSettingsView()
                    }
                }
            }
            .themeScreen()
            .navigationTitle("イコライザ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
