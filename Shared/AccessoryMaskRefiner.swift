import CoreImage
import CoreImage.CIFilterBuiltins

final class AccessoryMaskRefiner {
    private let context: CIContext
    private let temporal = AccessoryTemporalFilter()

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    func reset() { temporal.reset() }

    func refine(mask: CIImage, image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime,
                detail: AccessoryDetail = .standard) -> CIImage {
        let width = min(detail.rawValue, max(1, Int(image.extent.width.rounded())))
        let frame = sample(image, mask: mask, width: width)
        var evidence = frame.proposal().evidence
        if width > AccessoryDetail.standard.rawValue {
            // At finer scales gray metal can merge with the room through a few edge pixels.
            // Recover the material confirmed at the standard scale before updating history.
            let coarse = sample(image, mask: mask, width: AccessoryDetail.standard.rawValue)
            AccessoryRegions.restoreMetal(from: coarse, in: frame, evidence: &evidence)
        }
        let stable = temporal.filter(evidence, person: frame.alpha, rgba: frame.rgba,
                                     width: width, height: frame.height, time: time)
        guard stable.contains(where: { $0 != 0 }) else { return mask }
        let small = CIImage(bitmapData: Data(stable), bytesPerRow: width,
                            size: CGSize(width: width, height: frame.height), format: .L8, colorSpace: nil)
        let upsample = CIFilter.edgePreserveUpsample()
        upsample.inputImage = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        upsample.smallImage = small
        upsample.spatialSigma = 1.5
        upsample.lumaSigma = 0.08
        let fullBounds = CGRect(origin: .zero, size: image.extent.size)
        return FrameComposition.preserving(upsample.outputImage?.cropped(to: fullBounds) ?? small, in: mask)
    }

    private func sample(_ image: CIImage, mask: CIImage, width: Int) -> AccessorySamples {
        let height = max(1, Int(CGFloat(width) * image.extent.height / image.extent.width))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var alpha = [UInt8](repeating: 0, count: width * height)
        context.render(FrameComposition.alignMask(image, to: bounds), toBitmap: &rgba, rowBytes: width * 4,
                       bounds: bounds, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        context.render(FrameComposition.alignMask(mask, to: bounds), toBitmap: &alpha, rowBytes: width,
                       bounds: bounds, format: .L8, colorSpace: nil)
        return AccessorySamples(rgba: rgba, alpha: alpha, width: width, height: height)
    }
}
