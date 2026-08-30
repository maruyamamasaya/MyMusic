import SwiftUI
import UIKit

struct ActivityShareItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    private let temporaryDirectoryURL: URL

    init(file: MusicExportFile) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: file.filename)
            try file.data.write(to: url, options: .atomic)
            fileURL = url
            temporaryDirectoryURL = directory
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func removeTemporaryFile() {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        ActivityPopoverConfiguration.apply(to: controller)
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        ActivityPopoverConfiguration.apply(to: controller)
    }
}

enum ActivityPopoverConfiguration {
    static func apply(to controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        let sourceView = controller.view!
        popover.sourceView = sourceView
        popover.sourceRect = CGRect(
            x: sourceView.bounds.midX,
            y: sourceView.bounds.midY,
            width: 1,
            height: 1
        )
        popover.permittedArrowDirections = []
    }
}

extension View {
    func activityShareSheet(item: Binding<ActivityShareItem?>) -> some View {
        sheet(item: item) { shareItem in
            ActivityViewController(activityItems: [shareItem.fileURL])
                .onDisappear {
                    shareItem.removeTemporaryFile()
                }
        }
    }
}
