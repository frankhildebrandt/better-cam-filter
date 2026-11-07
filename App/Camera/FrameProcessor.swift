import CoreImage
import CoreMedia

/// CaptureEngine owns this processor and calls it only on its serial frame queue.
final class FrameProcessor {
    let context = CIContext(options: [.cacheIntermediates: false])
    private let segmentation = ForegroundSegmenter()
    private let accessoryRefiner: AccessoryMaskRefiner
    private var pool: CVPixelBufferPool?
    var background: CIImage?
    var segmentationMode = SegmentationMode.foregroundObjects
    var keepMask: CIImage?
    var accessoriesEnabled = true

    init() { accessoryRefiner = AccessoryMaskRefiner(context: context) }

    func process(_ input: CVPixelBuffer, at time: CMTime) throws -> CMSampleBuffer {
        if pool == nil { pool = try VideoBuffers.makePool() }
        guard let pool else { throw VideoError.allocation }
        let foreground = FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: CameraConfiguration.bounds)
        let outputImage: CIImage
        if let background {
            let automatic = try segmentation.mask(for: foreground, mode: segmentationMode)
            let mask = accessoriesEnabled && segmentationMode == .foregroundObjects
                ? accessoryRefiner.refine(mask: automatic, image: foreground) : automatic
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
