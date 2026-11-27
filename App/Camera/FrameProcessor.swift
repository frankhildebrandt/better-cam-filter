import CoreImage
import CoreMedia

/// Refines masks and composes analyzed frames.
/// CaptureEngine owns this processor and calls it only on its serial composition queue.
final class FrameProcessor {
    let context = CIContext(options: [.cacheIntermediates: false])
    private lazy var refiner = SegmentationRefiner(context: context)
    private let gestureReactions = GestureReactionProcessor()
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
    var segmentationConfiguration = SegmentationConfiguration() {
        didSet {
            if segmentationConfiguration != oldValue { refiner.configuration = segmentationConfiguration }
        }
    }
    var keepMask: CIImage?
    private(set) var previewMask: CIImage?
    /// Whether the last frame played a rear reaction, which the analysis stage must segment for.
    private(set) var reactionsNeedMask = false
    var gestureConfiguration: GestureConfiguration {
        get { gestureReactions.configuration }
        set { gestureReactions.configuration = newValue }
    }
    var detectedGesture: GestureKind? { gestureReactions.detectedGesture }
    var gestureError: String? { gestureReactions.error ?? reactionMaskError }
    private var reactionMaskError: String?

    func resetSegmentation() {
        refiner.reset()
        previewMask = nil
    }

    func resetGestures() {
        gestureReactions.reset()
        reactionMaskError = nil
        reactionsNeedMask = false
    }

    func previewReaction(_ reaction: ReactionKind, for gesture: GestureKind, at time: Double) {
        gestureReactions.preview(reaction, for: gesture, at: time)
    }

    /// Compose one analyzed frame. While the analysis stage has not yet learned that a background
    /// or reaction needs a mask, the frame passes through unmasked.
    func process(_ frame: AnalyzedFrame, keepPreviewMask: Bool) throws -> CMSampleBuffer {
        let size = CGSize(width: CVPixelBufferGetWidth(frame.input), height: CVPixelBufferGetHeight(frame.input))
        if size != inputSize {
            resetSegmentation()
            resetGestures()
            inputSize = size
        }
        if pool == nil { pool = try VideoBuffers.makePool(configuration: outputConfiguration) }
        guard let pool else { throw VideoError.allocation }
        let foreground = frame.foreground
        let reactions = gestureReactions.frame(for: foreground, at: frame.time.seconds)
        reactionsNeedMask = reactions.background != nil
        var outputImage = foreground
        var personMask: CIImage?
        reactionMaskError = nil
        previewMask = nil
        if let background {
            do {
                personMask = try mask(for: frame)
            } catch {
                resetSegmentation()
                throw error
            }
            if let personMask {
                previewMask = keepPreviewMask ? personMask : nil
                outputImage = FrameComposition.replaceBackground(foreground: foreground, background: background,
                                                                 mask: personMask, backgroundReaction: reactions.background)
            }
        }
        if reactions.background != nil, personMask == nil {
            do { personMask = try mask(for: frame) }
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
        return try VideoBuffers.makeSampleBuffer(buffer, at: frame.time, duration: outputConfiguration.frameDuration)
    }

    /// Refine the frame's raw segmentation with the keep mask; nil when the frame was not segmented.
    private func mask(for frame: AnalyzedFrame) throws -> CIImage? {
        guard let segmentation = frame.segmentation else { return nil }
        let automatic = refiner.refine(try segmentation.get(), image: frame.foreground, time: frame.time.seconds)
        return FrameComposition.preserving(keepMask, in: automatic)
    }
}
