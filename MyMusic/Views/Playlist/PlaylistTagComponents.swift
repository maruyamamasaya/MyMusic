import SwiftUI

struct PlaylistTagFilterBar: View {
    let tags: [String]
    @Binding var selectedTag: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                tagButton(title: "すべて", tag: nil)
                ForEach(tags, id: \.self) { tag in
                    tagButton(title: tag, tag: tag)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("プレイリストのタグ絞り込み")
    }

    private func tagButton(title: String, tag: String?) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = tag
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PlaylistTagSummary: View {
    let tags: [String]
    var maximumVisibleCount = 2

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 5) {
                ForEach(Array(tags.prefix(maximumVisibleCount)), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(.secondary)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                if tags.count > maximumVisibleCount {
                    Text("+\(tags.count - maximumVisibleCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("タグ: \(tags.joined(separator: "、"))")
        }
    }
}
