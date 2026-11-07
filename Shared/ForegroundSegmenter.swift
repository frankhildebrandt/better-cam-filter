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
            if configuration.customModelURL != oldValue.customModelURL
                || configuration.inferenceSettings != oldValue.inferenceSettings { custom = nil }
            reset()
        }
    }
    private var person = ForegroundSegmenter.makeRequest()
    private var custom: CustomForegroundSegmenter?
    private let maskRefiner = CustomMaskRefiner()
    private let maskTemporal = CustomMaskTemporalFilter()

    func reset() {
        person = Self.makeRequest(settings: configuration.appleSettings)
        maskTemporal.reset()
    }

    static func makeRequest(settings: AppleRecognitionSettings = .init()) -> VNGeneratePersonSegmentationRequest {
        let request = VNGeneratePersonSegmentationRequest()
        switch settings.quality {
        case .fast: request.qualityLevel = .fast
        case .balanced: request.qualityLevel = .balanced
        case .accurate: request.qualityLevel = .accurate
        }
        if VNGeneratePersonSegmentationRequest.supportedRevisions.contains(settings.revision) {
            request.revision = settings.revision
        }
        request.preferBackgroundProcessing = settings.preferBackgroundProcessing
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }

    /// Analyze the already cropped camera image, then map the full mask back without a second crop.
    func mask(for image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime) throws -> CIImage {
        let settings = configuration.maskSettings
        var mask: CIImage
        if configuration.provider == .custom {
            guard let url = configuration.customModelURL else { throw CustomSegmentationError.missingModel }
            if custom == nil { custom = try CustomForegroundSegmenter(modelURL: url, settings: configuration.inferenceSettings) }
            guard let custom else { throw CustomSegmentationError.missingModel }
            mask = try custom.mask(for: image)
            if settings.enabled && settings.personSupport {
                mask = FrameComposition.preserving(try personMask(for: image), in: mask)
            }
        } else { mask = try personMask(for: image) }
        guard settings.enabled else { return mask }
        mask = maskRefiner.refine(mask, settings: settings)
        return maskTemporal.filter(mask: mask, image: image, time: time, strength: settings.temporalStrength)
    }

    private func personMask(for image: CIImage) throws -> CIImage {
        let width = configuration.appleSettings.sanitized.analysisWidth
        let scale = width == 0 ? 1 : min(1, CGFloat(width) / image.extent.width)
        let analysis = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let handler = VNImageRequestHandler(ciImage: analysis, orientation: .up)
        try handler.perform([person])
        guard let result = person.results?.first else { throw VideoError.segmentation }
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: result.pixelBuffer), to: image.extent)
    }
}
