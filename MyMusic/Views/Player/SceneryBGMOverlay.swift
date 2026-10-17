import SwiftUI

/// A compact smoked-display BGM panel; playback and persistence remain outside the view.
struct SceneryBGMOverlay: View {
    @Environment(PlayerStore.self) private var music
    @Environment(\.scenePhase) private var scenePhase
    @State private var battery = SceneryBatteryService()
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let onReturn: () -> Void
    @Binding var isCollapsed: Bool

    @ScaledMetric(relativeTo: .body) private var artworkSize = 36
    @ScaledMetric(relativeTo: .caption) private var titleSize = 12
    @ScaledMetric(relativeTo: .caption) private var titleHeight = 15
    @ScaledMetric(relativeTo: .caption2) private var artistSize = 11
    @ScaledMetric(relativeTo: .caption2) private var artistHeight = 13
    @ScaledMetric(relativeTo: .caption2) private var labelSize = 9
    @ScaledMetric(relativeTo: .caption2) private var labelHeight = 11

    var body: some View {
        Group {
            if isCollapsed {
                trackCredit
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        trackCredit.frame(minWidth: 120)
                        playbackButtons
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        trackCredit
                        playbackButtons
                    }
                }
            }
        }
        .foregroundStyle(SceneryPlayerAppearance.display)
        .padding(.vertical, isCollapsed ? 2 : 4)
        .padding(.horizontal, 12)
        .background {
            ScenerySmokedPanel(opaque: reduceTransparency)
        }
        .overlay(alignment: .bottom) {
            playbackProgress
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
        }
        .overlay { if !reduceTransparency { SceneryGlassReflection() } }
        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : (isCollapsed ? 270 : 390), alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { battery.start() } else { battery.stop() }
        }
        .onDisappear { battery.stop() }
    }

    private var progress: Double {
        guard music.duration.isFinite, music.duration > 0,
              music.currentTime.isFinite else { return 0 }
        return min(1, max(0, music.currentTime / music.duration))
    }

    private var playbackProgress: some View {
        Canvas { context, size in
            let start: CGFloat = 5
            let end = max(start, size.width - 1)
            let playhead = start + (end - start) * progress
            var remaining = Path()
            for x in stride(from: start, through: end, by: 3) where x > playhead {
                remaining.addEllipse(in: CGRect(x: x - 0.4, y: 1.1, width: 0.8, height: 0.8))
            }
            context.fill(remaining, with: .color(SceneryPlayerAppearance.display.opacity(0.28)))
            if progress > 0 {
                let elapsed = Path(roundedRect: CGRect(x: start, y: 1, width: playhead - start, height: 1), cornerRadius: 0.5)
                context.fill(elapsed, with: .color(SceneryPlayerAppearance.display.opacity(0.85)))
                context.fill(Path(ellipseIn: CGRect(x: playhead - 0.8, y: 0.7, width: 1.6, height: 1.6)),
                             with: .color(SceneryPlayerAppearance.display))
            }
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0.75, width: 1.5, height: 1.5)),
                         with: .color(SceneryPlayerAppearance.display.opacity(music.isPlaying ? 0.95 : 0.3)))
        }
        .frame(height: 3)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("曲の再生位置")
        .accessibilityValue(music.duration.isFinite && music.duration > 0
            ? progress.formatted(.percent.precision(.fractionLength(0))) : "未取得")
    }

    private var trackCredit: some View {
        GeometryReader { geometry in
            let textWidth = max(0, geometry.size.width - max(44, artworkSize) - 9)
            HStack(spacing: 9) {
                Button(action: onReturn) {
                    AlbumArtworkView(artworkIdentifier: music.currentTrack?.artworkIdentifier)
                        .frame(width: artworkSize, height: artworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .accessibilityHidden(true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("通常の再生画面へ戻る")
                .accessibilityHint("車窓モードを閉じます")
                Button { isCollapsed.toggle() } label: { trackText(width: textWidth) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(music.currentTrack?.title ?? "未再生")、\(music.currentTrack?.artistName ?? "")")
                    .accessibilityHint(isCollapsed ? "再生操作を展開します" : "再生表示を縮小します")
            }
        }
        .frame(height: max(44, artworkSize, labelHeight + titleHeight + artistHeight + 2))
    }

    private func trackText(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ViewThatFits(in: .horizontal) {
                statusRow(compact: false)
                statusRow(compact: true)
            }
            .frame(height: labelHeight, alignment: .leading)
            HStack(spacing: 3) {
                SceneryDotRecord().frame(width: titleHeight - 1, height: titleHeight - 1)
                SceneryDisplayText(text: music.currentTrack?.title ?? "未再生", fontSize: titleSize, lineHeight: titleHeight)
            }
            SceneryDisplayText(text: music.currentTrack?.artistName ?? "", fontSize: artistSize, lineHeight: artistHeight)
                .foregroundStyle(SceneryPlayerAppearance.display.opacity(0.8))
        }
        .frame(width: width, alignment: .leading)
        .frame(minHeight: 44)
        .clipped()
        .contentShape(Rectangle())
    }

    private func statusRow(compact: Bool) -> some View {
        HStack(spacing: 4) {
            Text(music.isPlaying ? "NOW PLAYING" : "PAUSED")
                .font(.custom("DotGothic16-Regular", fixedSize: compact ? labelSize * 0.7 : labelSize))
                .tracking(compact ? 0 : 1)
                .foregroundStyle(SceneryPlayerAppearance.display.opacity(0.75))
                .fixedSize()
            Spacer(minLength: 2)
            SceneryBatteryIndicator(percentage: battery.percentage, isCharging: battery.isCharging, fontSize: compact ? labelSize * 0.7 : labelSize)
                .fixedSize()
            SceneryClock(fontSize: compact ? labelSize * 0.7 : labelSize)
        }
    }

    private var playbackButtons: some View {
        HStack(spacing: 0) {
            if let track = music.currentTrack, track.isEligibleForRegularPlayback {
                SceneryPreferenceControls(track: track)
            }
            Button { music.togglePlayPause() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(SceneryMetalPlaybackStyle(diameter: 36))
            .disabled(music.currentTrack == nil || music.isLoading)
            .accessibilityLabel(music.isPlaying ? "音楽を一時停止" : "音楽を再生")
            Button { music.next() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(SceneryMetalPlaybackStyle(diameter: 29))
            .disabled(!music.hasNext)
            .accessibilityLabel("次の曲")
        }
        .font(.system(.caption, design: .rounded))
        .buttonStyle(.plain)
    }
}
