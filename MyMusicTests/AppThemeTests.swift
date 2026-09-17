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

    func testVisualWorldSelectionIsIndependentOfThemeAndPersists() throws {
        let suite = "VisualWorldStyle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(AppTheme.blueCosmos.rawValue, forKey: "appearance.theme")
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.visualWorldStyle, .nightSky)

        settings.setVisualWorldStyle(.lightGates)
        settings.setTheme(.simpleDark)
        XCTAssertEqual(settings.visualWorldStyle, .lightGates)
        XCTAssertEqual(SettingsStore(defaults: defaults).visualWorldStyle, .lightGates)
        XCTAssertEqual(SettingsStore(defaults: defaults).theme, .simpleDark)
        settings.setVisualWorldStyle(.twilight)
        XCTAssertEqual(SettingsStore(defaults: defaults).visualWorldStyle, .twilight)
        settings.setVisualWorldStyle(.plasmaSpark)
        XCTAssertEqual(SettingsStore(defaults: defaults).visualWorldStyle, .plasmaSpark)
        settings.setVisualWorldStyle(.visualizer)
        XCTAssertEqual(SettingsStore(defaults: defaults).visualWorldStyle, .visualizer)
    }

    func testLegacyAuroraVisualWorldMigratesToPhotonSphere() throws {
        let suite = "VisualWorldLegacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("living-aurora", forKey: "appearance.visualWorldStyle")
        XCTAssertEqual(SettingsStore(defaults: defaults).visualWorldStyle, .photonSphere)
        XCTAssertEqual(defaults.string(forKey: "appearance.visualWorldStyle"), "simple-dark")
        XCTAssertEqual(VisualWorldStyle.allCases.count, 6)
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
