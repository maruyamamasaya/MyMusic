import AVFoundation
import AudioToolbox
import Foundation

@MainActor
protocol AudioInformationServicing: AnyObject {
    var outputChangeHandler: ((String, Double?) -> Void)? { get set }
    func information(for track: Track) async -> AudioInformation
}

@MainActor
final class AudioInformationService: AudioInformationServicing {
    var outputChangeHandler: ((String, Double?) -> Void)?

    private let fileImportService: FileImportServicing
    private var routeChangeToken: NSObjectProtocol?

    init(fileImportService: FileImportServicing? = nil) {
        self.fileImportService = fileImportService ?? FileImportService()
        let session = AVAudioSession.sharedInstance()
        routeChangeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let output = self.currentOutput()
                self.outputChangeHandler?(output.name, output.sampleRate)
            }
        }
    }

    isolated deinit {
        if let routeChangeToken { NotificationCenter.default.removeObserver(routeChangeToken) }
    }

    func information(for track: Track) async -> AudioInformation {
        let output = currentOutput()
        var information = AudioInformation(outputName: output.name, outputSampleRate: output.sampleRate)
        let folders = (try? fileImportService.restoreLibraryFolders()) ?? []
        let scopeURL = folders.first {
            track.fileURL.standardizedFileURL.pathComponents.starts(with: $0.standardizedFileURL.pathComponents)
        } ?? track.fileURL
        let hasAccess = scopeURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { scopeURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: track.fileURL.path) else { return information }

        do {
            let asset = AVURLAsset(url: track.fileURL)
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else { return information }
            let descriptions = try await audioTrack.load(.formatDescriptions)
            let estimatedDataRate = try? await audioTrack.load(.estimatedDataRate)
            guard let description = descriptions.first,
                  let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
                information.bitRate = Self.validBitRate(estimatedDataRate)
                return information
            }

            information.codec = Self.codecName(for: basicDescription.mFormatID)
            information.sampleRate = basicDescription.mSampleRate > 0 ? basicDescription.mSampleRate : nil
            information.bitDepth = basicDescription.mBitsPerChannel > 0 ? Int(basicDescription.mBitsPerChannel) : nil
            information.bitRate = Self.validBitRate(estimatedDataRate)
            information.channels = basicDescription.mChannelsPerFrame > 0 ? Int(basicDescription.mChannelsPerFrame) : nil
        } catch {
            // Audio information is optional and must never interrupt playback.
        }
        return information
    }

    private func currentOutput() -> (name: String, sampleRate: Double?) {
        let session = AVAudioSession.sharedInstance()
        let names = session.currentRoute.outputs.map(\.portName).filter { !$0.isEmpty }
        return (names.isEmpty ? "Unknown" : names.joined(separator: ", "), session.sampleRate > 0 ? session.sampleRate : nil)
    }

    private nonisolated static func validBitRate(_ value: Float?) -> Int? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return Int(value.rounded())
    }

    private nonisolated static func codecName(for formatID: AudioFormatID) -> String {
        switch formatID {
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatLinearPCM: return "PCM"
        default:
            let bytes = [24, 16, 8, 0].map { shift in UInt8((formatID >> shift) & 0xff) }
            let text = String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? "Unknown" : text
        }
    }
}
