import SwiftUI

struct LibraryFoldersView: View {
    @Environment(LibraryStore.self) private var libraryStore

    var body: some View {
        List {
            ForEach(libraryStore.libraryFolders) { folder in
                HStack {
                    Label(folder.name, systemImage: "folder")
                    Spacer()
                    Button(role: .destructive) {
                        Task { await libraryStore.removeFolder(folder) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(folder.name)を解除")
                }
            }
        }
        .navigationTitle("音楽フォルダ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
