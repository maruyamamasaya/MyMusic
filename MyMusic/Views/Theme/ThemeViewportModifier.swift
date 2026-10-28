import SwiftUI

/// One screen-space image composition shared by navigation, content and bottom controls.
struct ThemeViewportModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    @State private var viewport: CGRect?

    func body(content: Content) -> some View {
        content
            .background {
                ThemeBackground(theme: theme, extendsIntoSafeArea: false)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .global)
                    } action: { frame in
                        if frame.width > 0 && frame.height > 0 { viewport = frame }
                    }
                    .ignoresSafeArea()
            }
            .environment(\.themeBackgroundViewport, viewport)
    }
}
