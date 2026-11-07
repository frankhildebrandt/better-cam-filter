import CoreImage
import Vision

/// CaptureEngine owns this processor and calls it only on its serial frame queue.
final class FrameProcessor {
    let context = CIContext(options: [.cacheIntermediates: false])
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private var pool: CVPixelBufferPool?
    var background: CIImage?

    init() {
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    func process(_ input: CVPixelBuffer, at time: CMTime) throws -> CMSampleBuffer {
        if pool == nil { pool = try VideoBuffers.makePool() }
        guard let pool else { throw VideoError.allocation }
        let foreground = FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: CameraConfiguration.bounds)
        let outputImage: CIImage
        if let background {
            try VNImageRequestHandler(cvPixelBuffer: input, orientation: .up).perform([segmentation])
            guard let mask = segmentation.results?.first?.pixelBuffer else { throw VideoError.segmentation }
            // Apply the same crop to the source and mask so their silhouettes stay aligned.
            let alignedMask = FrameComposition.aspectFill(CIImage(cvPixelBuffer: mask), in: CameraConfiguration.bounds)
            outputImage = FrameComposition.replaceBackground(foreground: foreground, background: background, mask: alignedMask)
        } else {
            outputImage = foreground
        }
        let buffer = try VideoBuffers.makePixelBuffer(from: pool)
        context.render(outputImage, to: buffer, bounds: CameraConfiguration.bounds,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return try VideoBuffers.makeSampleBuffer(buffer, at: time)
    }
}
