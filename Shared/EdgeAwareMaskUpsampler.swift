import CoreImage
import CoreImage.CIFilterBuiltins

/// Upsamples a low-resolution mask so its edges follow the luminance edges of the full-resolution frame.
enum EdgeAwareMaskUpsampler {
    /// Stretch `mask` over `guide` like `FrameComposition.alignMask`, but snap transitions to hair,
    /// clothing and object outlines. Masks that are not smaller than the frame are only aligned.
    /// A narrow neighborhood (1.5 mask pixels) and luma sigma (0.08) keep thin cables from bleeding.
    static func upsample(_ mask: CIImage, guide: CIImage) -> CIImage {
        let bounds = guide.extent
        guard mask.extent.width < bounds.width || mask.extent.height < bounds.height,
              !mask.extent.isEmpty, !bounds.isEmpty, !bounds.isInfinite else {
            return FrameComposition.alignMask(mask, to: bounds)
        }
        let filter = CIFilter.edgePreserveUpsample()
        filter.inputImage = atOrigin(guide)
        filter.smallImage = atOrigin(mask)
        filter.spatialSigma = 1.5
        filter.lumaSigma = 0.08
        guard let output = filter.outputImage else { return FrameComposition.alignMask(mask, to: bounds) }
        return output.cropped(to: CGRect(origin: .zero, size: bounds.size))
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
    }

    private static func atOrigin(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }
}
