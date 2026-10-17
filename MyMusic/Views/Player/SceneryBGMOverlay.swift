import SwiftUI

/// A compact game-style BGM credit; no audio analysis or animation timer.
struct SceneryBGMOverlay: View {
    @Environment(PlayerStore.self) private var music
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var artworkSize = 36

    var body: some View {
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
        .foregroundStyle(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(reduceTransparency ? 1 : 0.58))
        }
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15)))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.65))
                .frame(width: 2, height: 30)
        }
        .overlay(alignment: .bottom) {
            playbackProgress
                .padding(.horizontal, 12)
                .padding(.bottom, 3)
        }
        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 410, alignment: .leading)
    }

    private var progress: Double {
        guard music.duration.isFinite, music.duration > 0,
              music.currentTime.isFinite else { return 0 }
        return min(1, max(0, music.currentTime / music.duration))
    }

    private var playbackProgress: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule().fill(.white.opacity(0.65))
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 1)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("曲の再生位置")
        .accessibilityValue(music.duration.isFinite && music.duration > 0
            ? progress.formatted(.percent.precision(.fractionLength(0))) : "未取得")
    }

    private var trackCredit: some View {
        HStack(spacing: 9) {
            AlbumArtworkView(artworkIdentifier: music.currentTrack?.artworkIdentifier)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(music.isPlaying ? "NOW PLAYING" : "PAUSED")
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
                Text(music.currentTrack?.title ?? "未再生")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                Text(music.currentTrack?.artistName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var playbackButtons: some View {
        HStack(spacing: 0) {
            if let track = music.currentTrack, track.isEligibleForRegularPlayback {
                TrackFavoriteButton(track: track, font: .caption, width: 36, favoriteColor: .red)
                PlaybackPreferenceButton(track: track, direction: .increase, compact: true)
                    .padding(.horizontal, 5)
            }
            Button { music.togglePlayPause() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
            }
            .disabled(music.currentTrack == nil || music.isLoading)
            .accessibilityLabel(music.isPlaying ? "音楽を一時停止" : "音楽を再生")
            Button { music.next() } label: {
                Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
            }
            .disabled(!music.hasNext)
            .accessibilityLabel("次の曲")
        }
        .font(.system(.caption, design: .rounded))
        .buttonStyle(.plain)
    }
}
