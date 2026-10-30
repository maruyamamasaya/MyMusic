import SwiftUI

struct WeeklyArtistRankingRowView: View {
    let row: ArtistRankingRow
    let rank: Int
    let metric: ArtistRankingMetric
    let movement: ArtistRankingMovement?
    let onOpen: () -> Void
    @ScaledMetric private var artworkSize = 44
    @ScaledMetric private var rankWidth = 38

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    if rank <= 3 {
                        Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                            .font(.caption2).accessibilityHidden(true)
                    }
                    Text("\(rank)").font(.title3.bold()).monospacedDigit()
                }
                .foregroundStyle(rankAccent)
                .frame(width: rankWidth)
                AlbumArtworkView(artworkIdentifier: row.artworkIdentifier)
                    .frame(width: artworkSize * artworkScale, height: artworkSize * artworkScale)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.title).font(.headline).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let movement {
                            Text(movement.title).font(.caption.bold()).monospacedDigit()
                                .foregroundStyle(movementColor(movement)).fixedSize()
                        }
                    }
                    Text("\(ArtistRankingFormatting.value(row, metric: metric)) ・ \(row.listeningDays)日聴いた")
                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if rank <= 10 {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [rankAccent.opacity(decorationOpacity), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(rank <= 10 ? rankAccent.opacity(rank <= 3 ? 0.65 : 0.3) : .primary.opacity(0.12),
                                  lineWidth: rank == 1 ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank)位、\(row.title)、\(metric.title)、\(ArtistRankingFormatting.value(row, metric: metric))、\(row.listeningDays)日聴いた")
        .accessibilityValue(movement?.accessibilityDescription ?? "")
        .accessibilityHint("点数の内訳と対象の曲を表示")
    }

    private var artworkScale: Double {
        switch rank {
        case 1: 1.36
        case 2: 1.23
        case 3: 1.09
        case 4...10: 1.045
        default: 1
        }
    }

    private var verticalPadding: CGFloat {
        switch rank {
        case 1: 20
        case 2: 17
        case 3: 15
        case 4...10: 14
        default: 12
        }
    }

    private var rankAccent: Color {
        switch rank {
        case 1: .orange
        case 2: .cyan
        case 3: .brown
        case 4...10: .purple
        default: .secondary
        }
    }

    private var decorationOpacity: Double {
        switch rank {
        case 1: 0.28
        case 2: 0.20
        case 3: 0.14
        default: 0.06
        }
    }

    private func movementColor(_ movement: ArtistRankingMovement) -> Color {
        switch movement {
        case .newEntry: .orange
        case .change(let places) where places > 0: .green
        case .change(let places) where places < 0: .red
        case .change: .secondary
        }
    }
}
