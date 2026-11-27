import CoreImage

/// Turns raw masks into the final foreground mask: person support, accessories, thresholds and temporal filtering.
/// Keeps per-pixel history and must stay on one serial queue.
final class SegmentationRefiner {
    var configuration = SegmentationConfiguration() { didSet { reset() } }
    private let maskRefiner = CustomMaskRefiner()
    private let maskTemporal: CustomMaskTemporalFilter
    private let accessories: AccessoryMaskRefiner

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        maskTemporal = CustomMaskTemporalFilter(context: context)
        accessories = AccessoryMaskRefiner(context: context)
    }

    func reset() {
        maskTemporal.reset()
        accessories.reset()
    }

    /// Refine the analysis of `image`. A supporting person mask is used only when the analysis contains one,
    /// so a frame analyzed just before a configuration change still refines safely.
    func refine(_ analysis: SegmentationAnalysis, image: CIImage, time: Double) -> CIImage {
        let settings = configuration.maskSettings
        let detail = configuration.appleSettings.accessoryDetail
        var mask = analysis.primary
        if settings.enabled {
            if var person = analysis.supportingPerson {
                if settings.accessorySupport {
                    person = accessories.refine(mask: person, image: image, time: time, detail: detail)
                }
                mask = FrameComposition.preserving(person, in: mask)
            }
            mask = maskRefiner.refine(mask, settings: settings)
            mask = maskTemporal.filter(mask: mask, image: image, time: time, strength: settings.temporalStrength)
        }
        if configuration.provider == .apple && configuration.appleAccessories.isActive {
            mask = accessories.refine(mask: mask, image: image, time: time, detail: detail)
        }
        return mask
    }
}
