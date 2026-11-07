import Foundation

struct InstalledSegmentationModel: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let catalogID: String?
    let name: String
    let modelURL: URL
}
