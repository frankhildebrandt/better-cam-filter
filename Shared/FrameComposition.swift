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

    static func replaceBackground(foreground: CIImage, background: CIImage, mask: CIImage,
                                  backgroundReaction: CIImage? = nil) -> CIImage {
        let bounds = foreground.extent
        let backdrop = aspectFill(background, in: bounds)
        return foreground.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: backgroundReaction?.composited(over: backdrop) ?? backdrop,
            kCIInputMaskImageKey: alignMask(mask, to: bounds)
        ]).cropped(to: bounds)
    }

    static func preserving(_ keepMask: CIImage?, in mask: CIImage) -> CIImage {
        guard let keepMask else { return mask }
        return mask.applyingFilter("CIMaximumCompositing", parameters: [
            kCIInputBackgroundImageKey: alignMask(keepMask, to: mask.extent)
        ]).cropped(to: mask.extent)
    }

    /// Rear effects use the existing person mask; front effects are part of the exported video.
    static func compositeReactions(over image: CIImage, foreground: CIImage?, background: CIImage?,
                                   personMask: CIImage?) -> CIImage {
        var result = image
        if let background, let personMask {
            result = image.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: background.composited(over: image),
                kCIInputMaskImageKey: alignMask(personMask, to: image.extent)
            ])
        }
        if let foreground { result = foreground.composited(over: result) }
        return result.cropped(to: image.extent)
    }
}
