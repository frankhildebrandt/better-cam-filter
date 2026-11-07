import CoreImage

final class AccessoryMaskRefiner {
    private let context: CIContext
    private let temporal = AccessoryTemporalFilter()

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    func reset() { temporal.reset() }

    func refine(mask: CIImage, image: CIImage, time: Double = ProcessInfo.processInfo.systemUptime) -> CIImage {
        let width = 512
        let height = max(1, Int(CGFloat(width) * image.extent.height / image.extent.width))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let smallImage = FrameComposition.alignMask(image, to: bounds)
        let smallMask = FrameComposition.alignMask(mask, to: bounds)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var alpha = [UInt8](repeating: 0, count: width * height)
        context.render(smallImage, toBitmap: &rgba, rowBytes: width * 4, bounds: bounds,
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        context.render(smallMask, toBitmap: &alpha, rowBytes: width, bounds: bounds,
                       format: .L8, colorSpace: nil)
        let proposal = AccessoryRegions.propose(rgba: rgba, alpha: alpha, width: width, height: height)
        let stable = temporal.filter(proposal.evidence, person: alpha, rgba: rgba,
                                     width: width, height: height, time: time)
        guard stable.contains(where: { $0 != 0 }) else { return mask }
        let additions = CIImage(bitmapData: Data(stable), bytesPerRow: width,
                                size: bounds.size, format: .L8, colorSpace: nil)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6]).cropped(to: bounds)
        return FrameComposition.preserving(additions, in: mask)
    }
}
