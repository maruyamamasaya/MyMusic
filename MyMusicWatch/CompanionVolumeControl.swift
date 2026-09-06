import SwiftUI
import WatchKit

/// The system volume control for audio playing on the paired iPhone.
/// WatchKit owns the displayed value and Digital Crown interaction.
struct CompanionVolumeControl: WKInterfaceObjectRepresentable {
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .companion)
    }

    func updateWKInterfaceObject(
        _ wkInterfaceObject: WKInterfaceVolumeControl,
        context: Context
    ) {}
}
