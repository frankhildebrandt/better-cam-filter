import CoreImage

/// Turn foreground confidence into controlled opacity, then adjust the boundary in output pixels.
struct CustomMaskRefiner {
    func refine(_ mask: CIImage, settings: CustomMaskSettings) -> CIImage {
        let settings = settings.sanitized
        guard settings.enabled else { return mask }
        let bounds = mask.extent
        guard !bounds.isEmpty, bounds.width.isFinite, bounds.height.isFinite else { return mask }
        let scale = 1 / settings.transition
        let bias = -(settings.threshold - settings.transition / 2) * scale
        var result = mask.clampedToExtent().applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: scale, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: scale, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: scale, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 1)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
        let radius = abs(settings.edgeInset) * bounds.height / 1080
        if radius > 0 {
            result = result.applyingFilter(settings.edgeInset > 0 ? "CIMorphologyMinimum" : "CIMorphologyMaximum",
                                           parameters: [kCIInputRadiusKey: radius])
        }
        return result.cropped(to: bounds)
    }
}
