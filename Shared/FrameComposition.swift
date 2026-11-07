import CoreImage

enum FrameComposition {
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
            kCIInputMaskImageKey: mask.transformed(by: CGAffineTransform(
                scaleX: bounds.width / mask.extent.width,
                y: bounds.height / mask.extent.height
            ))
        ]).cropped(to: bounds)
    }
}
