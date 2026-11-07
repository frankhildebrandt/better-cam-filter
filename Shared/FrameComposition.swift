import CoreImage

enum FrameComposition {
    /// Vision masks cover the entire image in normalized coordinates, even when their aspect ratios differ.
    static func alignMask(_ mask: CIImage, to bounds: CGRect) -> CIImage {
        let extent = mask.extent
        guard extent.width > 0, extent.height > 0 else { return mask }
        return mask.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: bounds.width / extent.width, y: bounds.height / extent.height))
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            .cropped(to: bounds)
    }

    /// Fills the target without stretching, cropping equally around the center.
    static func aspectFill(_ image: CIImage, in bounds: CGRect) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }
        let scale = max(bounds.width / extent.width, bounds.height / extent.height)
        let centered = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return centered.transformed(by: CGAffineTransform(
            translationX: bounds.midX - centered.extent.midX,
            y: bounds.midY - centered.extent.midY
        )).cropped(to: bounds)
    }

    static func replaceBackground(foreground: CIImage, background: CIImage, mask: CIImage) -> CIImage {
        let bounds = foreground.extent
        return foreground.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: aspectFill(background, in: bounds),
            kCIInputMaskImageKey: alignMask(mask, to: bounds)
        ]).cropped(to: bounds)
    }

    static func preserving(_ keepMask: CIImage?, in mask: CIImage) -> CIImage {
        guard let keepMask else { return mask }
        return mask.applyingFilter("CIMaximumCompositing", parameters: [
            kCIInputBackgroundImageKey: alignMask(keepMask, to: mask.extent)
        ]).cropped(to: mask.extent)
    }
}
