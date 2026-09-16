import SwiftUI

/// The only touch targets that execute playback commands in the art presentation.
struct VisualWorldController: View {
    @Environment(PlayerStore.self) private var player
    @Environment(\.appTheme) private var theme
    @Binding var expanded: Bool
    let suggestedDirection: Int
    let maximumHeight: CGFloat
    let onClose: () -> Void
    let onQueue: () -> Void
    let onEqualizer: () -> Void
    let onAddToPlaylist: () -> Void
    let onAudioInformation: () -> Void
    let onTrackAdjustments: () -> Void
    @State private var actionFeedback = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("タップして操作")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(expanded ? "詳細操作をたたむ" : "詳細操作を表示")
                Button(action: onClose) {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("コントローラーを閉じる")
            }
            HStack(spacing: 12) {
                transportButton("前の曲", symbol: "backward.end.fill", highlighted: suggestedDirection == -1,
                                enabled: player.hasPrevious && !player.isLoading, action: player.previous)
                transportButton(player.isPlaying ? "一時停止" : "再生",
                                symbol: player.isPlaying ? "pause.fill" : "play.fill", highlighted: false,
                                enabled: player.currentTrack != nil && !player.isLoading, action: player.togglePlayPause)
                transportButton("次の曲", symbol: "forward.end.fill", highlighted: suggestedDirection == 1,
                                enabled: player.hasNext && !player.isLoading, action: player.next)
            }
            if expanded {
                ScrollView {
                    details.padding(.top, 12)
                }
                .frame(maxHeight: max(44, maximumHeight - 130))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.13), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: actionFeedback)
    }

    private func transportButton(_ title: String, symbol: String, highlighted: Bool,
                                 enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            actionFeedback += 1
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(ThemePalette.resolve(theme).accent.opacity(highlighted ? 0.2 : 0.06),
                            in: RoundedRectangle(cornerRadius: 17))
        }
        .accessibilityLabel(title)
        .disabled(!enabled)
    }

    private var details: some View {
        VStack(spacing: 16) {
            ProgressBarView(currentTime: player.currentTime, duration: player.duration, onSeek: player.seek)
            HStack(spacing: 8) {
                Button("シャッフル", systemImage: "shuffle") { player.toggleShuffle() }
                    .foregroundStyle(player.isShuffleEnabled ? ThemePalette.resolve(theme).accent : Color.secondary)
                    .accessibilityValue(player.isShuffleEnabled ? "オン" : "オフ")
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("リピート", systemImage: player.repeatMode == .one ? "repeat.1" : "repeat") { player.cycleRepeatMode() }
                    .foregroundStyle(player.repeatMode == .off ? Color.secondary : ThemePalette.resolve(theme).accent)
                    .accessibilityValue(player.repeatMode == .off ? "オフ" : (player.repeatMode == .one ? "1曲" : "全曲"))
                    .frame(maxWidth: .infinity, minHeight: 44)
                if let track = player.currentTrack {
                    TrackFavoriteButton(track: track, font: .title3, width: 44)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    ListenLaterButton(track: track, font: .title3, width: 44)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .font(.title3)
            .labelStyle(.iconOnly)
            if let track = player.currentTrack {
                HStack {
                    PlaybackPreferenceButton(track: track, direction: .decrease)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    PlaybackPreferenceButton(track: track, direction: .increase)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    BoredomButton(track: track)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], spacing: 8) {
                detailButton("キュー", symbol: "list.bullet", action: onQueue)
                detailButton("イコライザ", symbol: "slider.vertical.3", action: onEqualizer)
                detailButton("プレイリスト", symbol: "text.badge.plus", action: onAddToPlaylist)
                    .disabled(player.currentTrack == nil)
                detailButton("オーディオ情報", symbol: "waveform", action: onAudioInformation)
                detailButton("曲別調整", symbol: "slider.horizontal.3", action: onTrackAdjustments)
            }
        }
    }

    private func detailButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
