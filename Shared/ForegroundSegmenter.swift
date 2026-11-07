import CoreImage
import Vision

enum SegmentationMode: String, CaseIterable, Identifiable, Sendable {
    case foregroundObjects, person
    var id: Self { self }
    var title: String {
        switch self {
        case .foregroundObjects: "Person + Objekte"
        case .person: "Nur Person"
        }
    }
}

/// Requests are stateful and must remain on the owning capture queue.
final class ForegroundSegmenter {
    private let person = VNGeneratePersonSegmentationRequest()
    private let objects = VNGenerateForegroundInstanceMaskRequest()

    init() {
        person.qualityLevel = .accurate
        person.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    /// Analyze the already cropped camera image, then map the full mask back without a second crop.
    func mask(for image: CIImage, mode: SegmentationMode) throws -> CIImage {
        let scale = min(1, 768 / image.extent.width)
        let analysis = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let handler = VNImageRequestHandler(ciImage: analysis, orientation: .up)
        let pixels: CVPixelBuffer
        switch mode {
        case .person:
            try handler.perform([person])
            guard let result = person.results?.first else { throw VideoError.segmentation }
            pixels = result.pixelBuffer
        case .foregroundObjects:
            try handler.perform([objects])
            guard let result = objects.results?.first else { throw VideoError.segmentation }
            if result.allInstances.isEmpty {
                return CIImage(color: .black).cropped(to: image.extent)
            }
            pixels = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        }
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: pixels), to: image.extent)
    }
}
