import CoreMedia
import Foundation

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
