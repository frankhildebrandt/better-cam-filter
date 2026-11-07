import Foundation

enum SegmentationProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple, custom

    var id: Self { self }
    var title: String {
        switch self {
        case .apple: "Apple Vision"
        case .custom: "Custom-Modell"
        }
    }
}

struct SegmentationConfiguration: Codable, Equatable, Sendable {
    var provider: SegmentationProvider = .apple
    var customModelURL: URL?
    var customModelName: String?
}
