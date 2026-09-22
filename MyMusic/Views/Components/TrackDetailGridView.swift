import SwiftUI

struct TrackDetailGridView: View {
    let title: String
    let items: [TrackDetailItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                    ForEach(items) { item in
                        GridRow {
                            Text(item.label)
                                .foregroundStyle(.secondary)
                            Text(item.value)
                                .monospacedDigit()
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
