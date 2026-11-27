import CoreImage
import Vision

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
    private let objects = VNGenerateForegroundInstanceMaskRequest()
    private var custom: CustomForegroundSegmenter?
    private let maskRefiner = CustomMaskRefiner()
    private let maskTemporal: CustomMaskTemporalFilter
    private let accessories: AccessoryMaskRefiner

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        maskTemporal = CustomMaskTemporalFilter(context: context)
        accessories = AccessoryMaskRefiner(context: context)
    }

    func reset() {
        person = Self.makeRequest(settings: configuration.appleSettings)
        maskTemporal.reset()
        accessories.reset()
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
    /// Vision requests share one handler so the analysis image is prepared only once per frame.
    func mask(for image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime) throws -> CIImage {
        let settings = configuration.maskSettings
        lazy var handler = analysisHandler(for: image)
        var mask: CIImage
        switch configuration.provider {
        case .custom:
            guard let url = configuration.customModelURL else { throw CustomSegmentationError.missingModel }
            if custom == nil { custom = try CustomForegroundSegmenter(modelURL: url, settings: configuration.inferenceSettings) }
            guard let custom else { throw CustomSegmentationError.missingModel }
            mask = try custom.mask(for: image)
        case .apple: mask = try personMask(for: image, using: handler)
        case .appleObjects: mask = try objectMask(for: image, using: handler)
        }
        if settings.enabled {
            if configuration.provider != .apple && settings.personSupport {
                var person = try personMask(for: image, using: handler)
                if settings.accessorySupport {
                    person = accessories.refine(mask: person, image: image, time: time, detail: configuration.appleSettings.accessoryDetail)
                }
                mask = FrameComposition.preserving(person, in: mask)
            }
            mask = maskRefiner.refine(mask, settings: settings)
            mask = maskTemporal.filter(mask: mask, image: image, time: time, strength: settings.temporalStrength)
        }
        if configuration.provider == .apple && configuration.appleAccessories.isActive {
            mask = accessories.refine(mask: mask, image: image, time: time, detail: configuration.appleSettings.accessoryDetail)
        }
        return mask
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
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: result.pixelBuffer), to: image.extent)
    }

    private func objectMask(for image: CIImage, using handler: VNImageRequestHandler) throws -> CIImage {
        objects.preferBackgroundProcessing = configuration.appleSettings.preferBackgroundProcessing
        try handler.perform([objects])
        guard let result = objects.results?.first, !result.allInstances.isEmpty else {
            return CIImage(color: .black).cropped(to: image.extent)
        }
        let pixels = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return FrameComposition.alignMask(CIImage(cvPixelBuffer: pixels, options: [.colorSpace: NSNull()]), to: image.extent)
    }
}
