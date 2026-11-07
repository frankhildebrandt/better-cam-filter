import CoreMedia
import Foundation

enum OutputResolution: String, Codable, CaseIterable, Identifiable, Sendable {
    case hd720, fullHD1080, qhd1440, uhd2160

    var id: Self { self }
    var width: Int {
        switch self {
        case .hd720: 1280
        case .fullHD1080: 1920
        case .qhd1440: 2560
        case .uhd2160: 3840
        }
    }
    var height: Int { width * 9 / 16 }
    var title: String {
        switch self {
        case .hd720: "HD · 1280 × 720"
        case .fullHD1080: "Full HD · 1920 × 1080"
        case .qhd1440: "QHD · 2560 × 1440"
        case .uhd2160: "4K · 3840 × 2160"
        }
    }
}

struct OutputConfiguration: Codable, Equatable, Sendable {
    static let frameRates: [Int32] = [15, 24, 25, 30, 60]
    var resolution: OutputResolution = .fullHD1080
    var frameRate: Int32 = 30

    var sanitized: Self {
        Self(resolution: resolution, frameRate: Self.frameRates.contains(frameRate) ? frameRate : 30)
    }
    var width: Int { resolution.width }
    var height: Int { resolution.height }
    var bounds: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }
    var frameDuration: CMTime { CMTime(value: 1, timescale: sanitized.frameRate) }
    var summary: String { "\(width) × \(height) · \(sanitized.frameRate) FPS" }
}

enum CameraConfiguration {
    static let name = "BetterCam"
    static let extensionIdentifier = "de.bettercam.camera"
    static let deviceID = UUID(uuidString: "9415D790-2322-4392-A9A8-9C675A7036B4")!
    static let sourceID = UUID(uuidString: "C0AB63F4-34A9-46CE-9FB7-ABCA30EC5DB0")!
    static let sinkID = UUID(uuidString: "F270A01C-A843-4832-B511-B5C6AE69A918")!
    static let width = 1920
    static let height = 1080
    static let frameRate: Int32 = 30
    static let frameDuration = CMTime(value: 1, timescale: frameRate)
    static let bounds = CGRect(x: 0, y: 0, width: width, height: height)
}
