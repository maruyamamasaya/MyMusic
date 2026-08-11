import SwiftUI

struct QueueView: View {
    var body: some View { EmptyStateView(icon: "text.line.last.and.arrowtriangle.forward", title: "Queue Is Empty", message: "Songs added to the queue will appear here.").navigationTitle("Queue") }
}
