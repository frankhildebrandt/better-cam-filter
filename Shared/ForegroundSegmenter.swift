import CoreImage
import Vision

enum SegmentationMode: String, CaseIterable, Identifiable, Sendable {
    case foregroundObjects, person
    var id: Self { self }
    var title: String {
        switch self {
        case .foregroundObjects: "Person + Zubehör"
        case .person: "Nur Person"
        }
    }
}

/// Requests are stateful and must remain on the owning capture queue.
final class ForegroundSegmenter {
    private var person = ForegroundSegmenter.makeRequest()

    func reset() { person = Self.makeRequest() }

    private static func makeRequest() -> VNGeneratePersonSegmentationRequest {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }

    /// Analyze the already cropped camera image, then map the full mask back without a second crop.
    func mask(for image: CIImage) throws -> CIImage {
        let scale = min(1, 768 / image.extent.width)
        let analysis = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let handler = VNImageRequestHandler(ciImage: analysis, orientation: .up)
        try handler.perform([person])
        guard let result = person.results?.first else { throw VideoError.segmentation }
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: result.pixelBuffer), to: image.extent)
    }
}
