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
    var configuration = SegmentationConfiguration() {
        didSet {
            if configuration.customModelURL != oldValue.customModelURL { custom = nil }
            reset()
        }
    }
    private var person = ForegroundSegmenter.makeRequest()
    private var custom: CustomForegroundSegmenter?
    private let maskRefiner = CustomMaskRefiner()
    private let maskTemporal = CustomMaskTemporalFilter()

    func reset() {
        person = Self.makeRequest()
        maskTemporal.reset()
    }

    private static func makeRequest() -> VNGeneratePersonSegmentationRequest {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }

    /// Analyze the already cropped camera image, then map the full mask back without a second crop.
    func mask(for image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime) throws -> CIImage {
        if configuration.provider == .custom {
            guard let url = configuration.customModelURL else { throw CustomSegmentationError.missingModel }
            if custom == nil { custom = try CustomForegroundSegmenter(modelURL: url) }
            guard let custom else { throw CustomSegmentationError.missingModel }
            let settings = configuration.maskSettings
            var mask = try custom.mask(for: image)
            guard settings.enabled else { return mask }
            if settings.personSupport {
                mask = FrameComposition.preserving(try personMask(for: image), in: mask)
            }
            mask = maskRefiner.refine(mask, settings: settings)
            return maskTemporal.filter(mask: mask, image: image, time: time, strength: settings.temporalStrength)
        }
        return try personMask(for: image)
    }

    private func personMask(for image: CIImage) throws -> CIImage {
        let scale = min(1, 768 / image.extent.width)
        let analysis = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let handler = VNImageRequestHandler(ciImage: analysis, orientation: .up)
        try handler.perform([person])
        guard let result = person.results?.first else { throw VideoError.segmentation }
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: result.pixelBuffer), to: image.extent)
    }
}
