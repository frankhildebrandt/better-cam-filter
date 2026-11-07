import CoreImage
import CoreMedia

/// CaptureEngine owns this processor and calls it only on its serial frame queue.
final class FrameProcessor {
    let context = CIContext(options: [.cacheIntermediates: false])
    private let segmentation = ForegroundSegmenter()
    private let gestureReactions = GestureReactionProcessor()
    private let accessoryRefiner: AccessoryMaskRefiner
    private var pool: CVPixelBufferPool?
    private var inputSize = CGSize.zero
    var outputConfiguration = OutputConfiguration() {
        didSet {
            guard outputConfiguration != oldValue else { return }
            pool = nil
            resetSegmentation()
            resetGestures()
        }
    }
    var background: CIImage? { didSet { resetSegmentation() } }
    var segmentationMode = SegmentationMode.foregroundObjects { didSet { resetSegmentation() } }
    var segmentationConfiguration = SegmentationConfiguration() {
        didSet {
            segmentation.configuration = segmentationConfiguration
            accessoryRefiner.reset()
        }
    }
    var keepMask: CIImage?
    var accessoriesEnabled = true { didSet { resetSegmentation() } }
    private(set) var previewMask: CIImage?
    var gestureConfiguration: GestureConfiguration {
        get { gestureReactions.configuration }
        set { gestureReactions.configuration = newValue }
    }
    var detectedGesture: GestureKind? { gestureReactions.detectedGesture }
    var gestureError: String? { gestureReactions.error ?? reactionMaskError }
    private var reactionMaskError: String?

    init() { accessoryRefiner = AccessoryMaskRefiner(context: context) }

    func resetSegmentation() {
        segmentation.reset()
        accessoryRefiner.reset()
        previewMask = nil
    }

    func resetGestures() {
        gestureReactions.reset()
        reactionMaskError = nil
    }

    func previewReaction(_ reaction: ReactionKind, for gesture: GestureKind, at time: Double) {
        gestureReactions.preview(reaction, for: gesture, at: time)
    }

    func process(_ input: CVPixelBuffer, at time: CMTime) throws -> CMSampleBuffer {
        let size = CGSize(width: CVPixelBufferGetWidth(input), height: CVPixelBufferGetHeight(input))
        if size != inputSize {
            resetSegmentation()
            resetGestures()
            inputSize = size
        }
        if pool == nil { pool = try VideoBuffers.makePool(configuration: outputConfiguration) }
        guard let pool else { throw VideoError.allocation }
        let foreground = FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: outputConfiguration.bounds)
        let reactions = gestureReactions.frame(for: foreground, at: time.seconds)
        let outputImage: CIImage
        var personMask: CIImage?
        reactionMaskError = nil
        if let background {
            let preserved: CIImage
            do {
                preserved = try mask(for: foreground, at: time.seconds)
            } catch {
                resetSegmentation()
                throw error
            }
            personMask = preserved
            previewMask = preserved
            outputImage = FrameComposition.replaceBackground(foreground: foreground, background: background,
                                                             mask: preserved, backgroundReaction: reactions.background)
        } else {
            previewMask = nil
            outputImage = foreground
        }
        if reactions.background != nil, personMask == nil {
            do { personMask = try mask(for: foreground, at: time.seconds) }
            catch {
                // Optional reaction masking must not interrupt an otherwise healthy camera stream.
                reactionMaskError = "Reaction-Hintergrund konnte nicht freigestellt werden: \(error.localizedDescription)"
                resetSegmentation()
            }
        }
        let composed = FrameComposition.compositeReactions(over: outputImage, foreground: reactions.foreground,
                                                           background: background == nil ? reactions.background : nil,
                                                           personMask: personMask)
        let buffer = try VideoBuffers.makePixelBuffer(from: pool)
        context.render(composed, to: buffer, bounds: outputConfiguration.bounds,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return try VideoBuffers.makeSampleBuffer(buffer, at: time, duration: outputConfiguration.frameDuration)
    }

    private func mask(for image: CIImage, at time: Double) throws -> CIImage {
        let automatic = try segmentation.mask(for: image, time: time)
        let refined = segmentationConfiguration.provider == .apple && accessoriesEnabled && segmentationMode == .foregroundObjects
            ? accessoryRefiner.refine(mask: automatic, image: image, time: time) : automatic
        return FrameComposition.preserving(keepMask, in: refined)
    }
}
