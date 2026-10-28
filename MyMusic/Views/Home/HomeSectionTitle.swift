import SwiftUI

/// One accented grapheme in a section heading.
struct HomeSectionTitle: View {
    @Environment(\.appTheme) private var theme
    let text: String

    init(_ text: String) { self.text = text }

    private var styledText: AttributedString {
        var value = AttributedString(text)
        if !value.characters.isEmpty {
            let start = value.startIndex
            let end = value.characters.index(after: start)
            value[start..<end].foregroundColor = ThemePalette.resolve(theme).accent
        }
        return value
    }

    var body: some View {
        Text(styledText)
            .font(ThemeTypography.sectionTitle(for: theme))

    }
}
