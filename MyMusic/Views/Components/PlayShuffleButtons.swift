import SwiftUI

struct PlayShuffleButtons: View {
    let isDisabled: Bool
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            actionButton(
                title: "再生",
                systemImage: "play.fill",
                action: onPlay
            )

            actionButton(
                title: "シャッフル",
                systemImage: "shuffle",
                action: onShuffle
            )
        }
        .disabled(isDisabled)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(title)
    }
}
