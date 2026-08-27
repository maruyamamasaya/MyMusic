import SwiftUI

struct TrackFeatureBadgeView: View {
    let track: Track
    let feature: TrackFeature
    @State private var isDetailPresented = false

    private var badges: [TrackFeatureDisplayItem] {
        TrackFeaturePresentation.badgeItems(for: feature.values)
    }

    var body: some View {
        Button {
            isDetailPresented = true
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) { badgeLabels }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 7) { badgeLabels }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badges.isEmpty ? "音楽特徴" : "音楽特徴、\(badges.map(\.label).joined(separator: "、"))")
        .accessibilityHint("音楽特徴の詳細を表示")
        .sheet(isPresented: $isDetailPresented) {
            NavigationStack {
                TrackFeatureDetailView(track: track)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { isDetailPresented = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var badgeLabels: some View {
        if badges.isEmpty {
            // Low scores must not imply a confident classification, but remain inspectable.
            Label("音楽特徴", systemImage: "waveform")
                .badgeStyle()
        } else {
            ForEach(badges) { badge in
                Text(badge.label)
                    .badgeStyle()
            }
        }
    }
}

private extension View {
    func badgeStyle() -> some View {
        font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(.tint)
            .background(.tint.opacity(0.12), in: Capsule())
    }
}
