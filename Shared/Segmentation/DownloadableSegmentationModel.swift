import Foundation

struct DownloadableSegmentationModel: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let downloadURL: URL
    let sourceURL: URL
    let license: String
    let byteCount: Int64
    let sha256: String
    let fileName: String
}
