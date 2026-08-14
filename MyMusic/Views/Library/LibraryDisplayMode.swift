import SwiftUI

enum LibraryDisplayMode: String {
    case text
    case artwork

    var title: String {
        switch self {
        case .text: "テキスト"
        case .artwork: "ジャケット"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "list.bullet"
        case .artwork: "square.grid.2x2"
        }
    }
}

struct LibraryDisplayModeMenu: View {
    @Binding var selection: LibraryDisplayMode

    var body: some View {
        Menu {
            Picker("表示形式", selection: $selection) {
                Label(LibraryDisplayMode.text.title, systemImage: LibraryDisplayMode.text.systemImage)
                    .tag(LibraryDisplayMode.text)
                Label(LibraryDisplayMode.artwork.title, systemImage: LibraryDisplayMode.artwork.systemImage)
                    .tag(LibraryDisplayMode.artwork)
            }
        } label: {
            Label("表示形式", systemImage: selection.systemImage)
        }
    }
}
