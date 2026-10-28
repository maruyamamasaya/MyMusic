import SwiftUI
import UIKit

/// Japanese themes use Reisho or bold Mincho headings; body and controls stay standard.
@MainActor
enum ThemeTypography {
    private static let minchoName = UIFont(name: "HiraMinProN-W3", size: 24)?.fontName
    private static let boldMinchoName = UIFont(name: "HiraMinProN-W6", size: 24)?.fontName

    private static func japaneseFont(for theme: AppTheme, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if theme == .reimei {
            if let boldMinchoName { return .custom(boldMinchoName, size: size, relativeTo: style) }
            if let minchoName { return .custom(minchoName, size: size, relativeTo: style).bold() }
            return .system(style, design: .serif, weight: .bold)
        }
        if theme == .sumiWashi { return .custom("aoyagireisyo2", size: size, relativeTo: style) }
        if let minchoName { return .custom(minchoName, size: size, relativeTo: style) }
        return .system(style, design: .serif, weight: .regular)
    }

    static func sectionTitle(for theme: AppTheme) -> Font {
        switch theme {
        case .sumiWashi, .reimei: japaneseFont(for: theme, size: 20, relativeTo: .title3)
        default: .title3.bold()
        }
    }

    static func trackTitle(for theme: AppTheme) -> Font {
        switch theme {
        case .sumiWashi, .reimei: japaneseFont(for: theme, size: 22, relativeTo: .title2)
        default: .title2.bold()
        }
    }

    static func themeTitle(for theme: AppTheme) -> Font {
        switch theme {
        case .sumiWashi, .reimei: japaneseFont(for: theme, size: 22, relativeTo: .title2)
        default: .title2.weight(.semibold)
        }
    }
}
