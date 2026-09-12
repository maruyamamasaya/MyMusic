import XCTest
import SwiftUI
@testable import MyMusic

@MainActor
final class AppThemeTests: XCTestCase {
    func testPreferenceRoundTripAndUnknownValueFallback() throws {
        let suite = "AppThemeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(SettingsStore(defaults: defaults).theme, .livingAurora)
        XCTAssertEqual(AppTheme.allCases.first, .simpleDark)
        for theme in AppTheme.allCases {
            SettingsStore(defaults: defaults).setTheme(theme)
            XCTAssertEqual(SettingsStore(defaults: defaults).theme, theme)
        }
        defaults.set("future-theme", forKey: "appearance.theme")
        XCTAssertEqual(SettingsStore(defaults: defaults).theme, .livingAurora)
    }

    func testThemeSelectionRendersForEveryThemeAndAccessibilitySize() throws {
        let suite = "AppThemeRender.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        for theme in AppTheme.allCases {
            settings.setTheme(theme)
            for large in [false, true] {
                let view = ThemeCatalogView()
                    .environment(settings)
                    .environment(\.appTheme, theme)
                    .environment(\.colorScheme, .dark)
                    .environment(\.dynamicTypeSize, large ? .accessibility3 : .large)
                    .frame(width: 393)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(ThemePalette.resolve(theme).base)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, 393)
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("theme-\(theme.rawValue)-\(large ? "large" : "standard").png")
                try XCTUnwrap(image.pngData()).write(to: url)
                print("THEME_RENDER \(url.path)")
            }
        }
    }
}
