import SwiftUI

struct ProgressBarView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var dragValue: TimeInterval = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: $dragValue,
                in: 0...maximumDuration,
                onEditingChanged: { editing in
                    isDragging = editing
                    if !editing { onSeek(dragValue) }
                }
            )
            .disabled(duration <= 0)
            .accessibilityLabel("Playback position")
            .accessibilityValue(TimeFormatter.string(from: displayedTime))

            HStack {
                Text(TimeFormatter.string(from: displayedTime))
                Spacer()
                Text(TimeFormatter.string(from: max(duration, 0)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .onAppear { synchronizeDragValue() }
        .onChange(of: currentTime) { _, _ in
            if !isDragging { synchronizeDragValue() }
        }
        .onChange(of: duration) { _, _ in
            if !isDragging { synchronizeDragValue() }
        }
    }

    private var maximumDuration: TimeInterval { max(duration, 1) }
    private var displayedTime: TimeInterval { isDragging ? dragValue : currentTime }

    private func synchronizeDragValue() {
        dragValue = min(max(currentTime, 0), maximumDuration)
    }
}
