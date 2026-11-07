import CoreImage
import CoreMedia

/// CaptureEngine owns this processor and calls it only on its serial frame queue.
final class FrameProcessor {
    let context = CIContext(options: [.cacheIntermediates: false])
    private let segmentation = ForegroundSegmenter()
    private let accessoryRefiner: AccessoryMaskRefiner
    private var pool: CVPixelBufferPool?
    private var inputSize = CGSize.zero
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

    init() { accessoryRefiner = AccessoryMaskRefiner(context: context) }

    func resetSegmentation() {
        segmentation.reset()
        accessoryRefiner.reset()
    }

    func process(_ input: CVPixelBuffer, at time: CMTime) throws -> CMSampleBuffer {
        let size = CGSize(width: CVPixelBufferGetWidth(input), height: CVPixelBufferGetHeight(input))
        if size != inputSize {
            resetSegmentation()
            inputSize = size
        }
        if pool == nil { pool = try VideoBuffers.makePool() }
        guard let pool else { throw VideoError.allocation }
        let foreground = FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: CameraConfiguration.bounds)
        let outputImage: CIImage
        if let background {
            let mask: CIImage
            do {
                let automatic = try segmentation.mask(for: foreground)
                mask = segmentationConfiguration.provider == .apple && accessoriesEnabled && segmentationMode == .foregroundObjects
                    ? accessoryRefiner.refine(mask: automatic, image: foreground, time: time.seconds) : automatic
            } catch {
                resetSegmentation()
                throw error
            }
            let preserved = FrameComposition.preserving(keepMask, in: mask)
            outputImage = FrameComposition.replaceBackground(foreground: foreground, background: background, mask: preserved)
        } else {
            outputImage = foreground
        }
        let buffer = try VideoBuffers.makePixelBuffer(from: pool)
        context.render(outputImage, to: buffer, bounds: CameraConfiguration.bounds,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return try VideoBuffers.makeSampleBuffer(buffer, at: time)
    }
}
