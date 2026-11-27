import CoreImage
import Foundation

enum SegmentationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case foregroundObjects, person
    var id: Self { self }
    var title: String {
        switch self {
        case .foregroundObjects: "Person + Zubehör"
        case .person: "Nur Person"
        }
    }
}

/// Synchronous analysis and refinement for tools and tests.
/// The camera pipeline runs `SegmentationAnalyzer` and `SegmentationRefiner` on separate queues instead.
final class ForegroundSegmenter {
    var configuration = SegmentationConfiguration() {
        didSet {
            analyzer.configuration = configuration
            refiner.configuration = configuration
        }
    }
    private let analyzer = SegmentationAnalyzer()
    private let refiner: SegmentationRefiner

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        refiner = SegmentationRefiner(context: context)
    }

    func reset() {
        analyzer.reset()
        refiner.reset()
    }

    func mask(for image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime) throws -> CIImage {
        refiner.refine(try analyzer.analyze(image), image: image, time: time)
    }
}
