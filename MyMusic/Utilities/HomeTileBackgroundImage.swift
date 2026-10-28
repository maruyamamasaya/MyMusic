import UIKit

enum HomeTileBackgroundImage {
    static let manualQueueVariantNames = ["manual-queue-cards", "manual-queue-cassettes", "manual-queue-notes"]
    static let stationImageName = "station-background"
    static let stationVariantNames = [stationImageName, "station-golden-island", "station-golden-spiral"]
    static let highlightVariantNames = [
        "highlight-vivid-coral", "highlight-vivid-ocean", "highlight-vivid-violet", "highlight-vivid-lime"
    ]
    static let highlightImageName = "highlight-background"
    static let supportedExtensions = ["jpg", "jpeg", "png", "heic"]

    static func load(named baseName: String, bundle: Bundle = .main) -> UIImage? {
        for fileExtension in supportedExtensions {
            for subdirectory in ["Resources/HomeTileImages", "HomeTileImages"] {
                if let url = bundle.url(
                    forResource: baseName,
                    withExtension: fileExtension,
                    subdirectory: subdirectory
                ), let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }

            if let url = bundle.url(forResource: baseName, withExtension: fileExtension),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return nil
    }
}
