import CoreImage
import Vision

/// Raw model output for one frame, before refinement. Masks cover the analyzed image's extent.
struct SegmentationAnalysis {
    let primary: CIImage
    /// Vision's person mask, when a non-person provider should be supported by it.
    let supportingPerson: CIImage?
}

/// Runs Vision or Core ML on a frame. Vision requests are stateful and must stay on one serial queue.
final class SegmentationAnalyzer {
    var configuration = SegmentationConfiguration() {
        didSet {
            if configuration.customModelURL != oldValue.customModelURL
                || configuration.inferenceSettings != oldValue.inferenceSettings { custom = nil }
            reset()
        }
    }
    private var person = SegmentationAnalyzer.makeRequest()
    private let objects = VNGenerateForegroundInstanceMaskRequest()
    private var custom: CustomForegroundSegmenter?

    /// Start a new video sequence; Vision smooths person masks across frames of one request.
    func reset() {
        person = Self.makeRequest(settings: configuration.appleSettings)
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

    /// Analyze the already cropped camera image; masks map back to its full extent without a second crop.
    /// Vision requests share one handler so the analysis image is prepared only once per frame.
    func analyze(_ image: CIImage) throws -> SegmentationAnalysis {
        lazy var handler = analysisHandler(for: image)
        let primary: CIImage
        switch configuration.provider {
        case .custom:
            guard let url = configuration.customModelURL else { throw CustomSegmentationError.missingModel }
            if custom == nil { custom = try CustomForegroundSegmenter(modelURL: url, settings: configuration.inferenceSettings) }
            guard let custom else { throw CustomSegmentationError.missingModel }
            primary = try custom.mask(for: image)
        case .apple: primary = try personMask(for: image, using: handler)
        case .appleObjects: primary = try objectMask(for: image, using: handler)
        }
        let settings = configuration.maskSettings
        let needsPerson = settings.enabled && settings.personSupport && configuration.provider != .apple
        return SegmentationAnalysis(primary: primary,
                                    supportingPerson: needsPerson ? try personMask(for: image, using: handler) : nil)
    }

    private func analysisHandler(for image: CIImage) -> VNImageRequestHandler {
        let width = configuration.appleSettings.sanitized.analysisWidth
        let scale = width == 0 ? 1 : min(1, CGFloat(width) / image.extent.width)
        let analysis = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return VNImageRequestHandler(ciImage: analysis, orientation: .up)
    }

    private func personMask(for image: CIImage, using handler: VNImageRequestHandler) throws -> CIImage {
        try handler.perform([person])
        guard let result = person.results?.first else { throw VideoError.segmentation }
        return EdgeAwareMaskUpsampler.upsample(CIImage(cvPixelBuffer: result.pixelBuffer), guide: image)
    }

    private func objectMask(for image: CIImage, using handler: VNImageRequestHandler) throws -> CIImage {
        objects.preferBackgroundProcessing = configuration.appleSettings.preferBackgroundProcessing
        try handler.perform([objects])
        guard let result = objects.results?.first, !result.allInstances.isEmpty else {
            return CIImage(color: .black).cropped(to: image.extent)
        }
        let pixels = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return EdgeAwareMaskUpsampler.upsample(CIImage(cvPixelBuffer: pixels, options: [.colorSpace: NSNull()]), guide: image)
    }
}
