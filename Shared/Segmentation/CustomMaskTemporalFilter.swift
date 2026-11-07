import CoreImage

/// Bridge brief confidence losses only where the camera still sees the same foreground appearance.
final class CustomMaskTemporalFilter {
    private let context: CIContext
    private var retained = [UInt8]()
    private var colors = [UInt8]()
    private var missingSince = [Double]()
    private var sourceExtent = CGRect.null
    private var maskExtent = CGRect.null
    private var lastTime: Double?
    private var lastStrength = 0.0

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    func reset() {
        retained = []
        colors = []
        missingSince = []
        sourceExtent = .null
        maskExtent = .null
        lastTime = nil
        lastStrength = 0
    }

    func filter(mask: CIImage, image: CIImage, time: Double, strength: Double) -> CIImage {
        guard strength.isFinite, strength > 0, time.isFinite,
              image.extent.width.isFinite, image.extent.height.isFinite,
              image.extent.width > 0, image.extent.height > 0,
              !mask.extent.isInfinite, !mask.extent.isEmpty else { reset(); return mask }
        let amount = min(1, strength)
        let width = max(1, min(320, Int(image.extent.width.rounded())))
        let height = max(1, Int((CGFloat(width) * image.extent.height / image.extent.width).rounded()))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let count = width * height
        let discontinuity = lastTime.map { time < $0 || time - $0 > 0.3 } ?? false
        if retained.count != count || sourceExtent != image.extent || maskExtent != mask.extent
            || lastStrength != amount || discontinuity {
            reset()
            retained = [UInt8](repeating: 0, count: count)
            missingSince = [Double](repeating: -1, count: count)
            colors = [UInt8](repeating: 0, count: count * 4)
        }
        sourceExtent = image.extent
        maskExtent = mask.extent
        lastTime = time
        lastStrength = amount
        var rgba = [UInt8](repeating: 0, count: count * 4)
        var alpha = [UInt8](repeating: 0, count: count)
        context.render(FrameComposition.alignMask(image, to: bounds), toBitmap: &rgba, rowBytes: width * 4,
                       bounds: bounds, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        context.render(FrameComposition.alignMask(mask, to: bounds), toBitmap: &alpha, rowBytes: width,
                       bounds: bounds, format: .L8, colorSpace: nil)
        var held = [UInt8](repeating: 0, count: count)
        for pixel in alpha.indices {
            if alpha[pixel] >= 224 {
                retained[pixel] = alpha[pixel]
                missingSince[pixel] = -1
                for channel in 0..<3 { colors[pixel * 4 + channel] = rgba[pixel * 4 + channel] }
            } else if retained[pixel] > 0 {
                if missingSince[pixel] < 0 { missingSince[pixel] = time }
                let sameAppearance = (0..<3).allSatisfy {
                    abs(Int(colors[pixel * 4 + $0]) - Int(rgba[pixel * 4 + $0])) <= 24
                }
                if sameAppearance && time - missingSince[pixel] < 0.12 * amount {
                    held[pixel] = retained[pixel]
                } else { retained[pixel] = 0; missingSince[pixel] = -1 }
            }
        }
        guard held.contains(where: { $0 != 0 }) else { return mask }
        let additions = CIImage(bitmapData: Data(held), bytesPerRow: width,
                                size: bounds.size, format: .L8, colorSpace: nil)
        return FrameComposition.preserving(additions, in: mask)
    }
}
