import UIKit

protocol ArtworkServicing: AnyObject {
    func artwork(for identifier: String) async -> UIImage?
}

final class ArtworkService: ArtworkServicing {
    func artwork(for identifier: String) async -> UIImage? { nil }
}
