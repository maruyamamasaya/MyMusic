import SwiftUI

struct MusicHistoryMetric: Identifiable {
    let title: String
    let value: Int
    let unit: String

    var id: String { title }
}

struct MusicHistorySectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

struct MusicHistoryHeroView: View {
    let eyebrow: String
    let item: MusicHistorySnapshot.TrackRanking
    let artworkMaxWidth: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            Text(eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(maxWidth: artworkMaxWidth)
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)

            Text(item.track.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(item.track.artistName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("\(item.playCount)回再生")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct MusicHistoryMetricsView: View {
    let metrics: [MusicHistoryMetric]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(metric.value, format: .number)
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text(metric.unit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(metric.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(12)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct MusicHistoryTrackTile: View {
    let item: MusicHistorySnapshot.TrackRanking
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.track.title)
                .font(.headline)
                .lineLimit(2)
            Text(item.track.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(item.playCount)回")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MusicHistoryArtistTile: View {
    let item: MusicHistorySnapshot.ArtistRanking
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.representativeTrack.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.name)
                .font(.headline)
                .lineLimit(2)
            Text("\(item.playCount)回")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MusicHistoryMonthTile: View {
    let month: MusicHistorySnapshot.Month

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: month.mostPlayedTrack?.track.artworkIdentifier)
            Text(month.date, format: .dateTime.month(.wide))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(month.mostPlayedTrack?.track.title ?? "再生履歴なし")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("月の音楽史を表示")
    }
}

struct MusicHistoryTrackRow: View {
    let rank: Int
    let item: MusicHistorySnapshot.TrackRanking

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(item.playCount)回")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
