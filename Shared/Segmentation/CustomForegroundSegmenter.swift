import CoreImage
import CoreML

/// Runs a stateless, single-image foreground-alpha model on the capture queue.
final class CustomForegroundSegmenter {
    private let model: MLModel
    private let inputName: String
    private let outputName: String
    private let input: MLImageConstraint
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var inputBuffer: CVPixelBuffer?

    init(modelURL: URL) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
        let description = model.modelDescription
        guard description.inputDescriptionsByName.count == 1,
              let feature = description.inputDescriptionsByName.values.first,
              !feature.isOptional, let constraint = feature.imageConstraint,
              constraint.pixelsWide > 0, constraint.pixelsHigh > 0,
              [kCVPixelFormatType_32BGRA, kCVPixelFormatType_OneComponent8,
               kCVPixelFormatType_OneComponent16Half].contains(constraint.pixelFormatType) else {
            throw CustomSegmentationError.unsupportedInput
        }
        if #available(macOS 15.0, *), !description.stateDescriptionsByName.isEmpty {
            throw CustomSegmentationError.unsupportedInput
        }
        inputName = feature.name
        input = constraint
        let output = try Self.maskOutput(in: description)
        if let image = output.imageConstraint {
            guard [kCVPixelFormatType_OneComponent8, kCVPixelFormatType_OneComponent16Half,
                   kCVPixelFormatType_OneComponent32Float].contains(image.pixelFormatType) else {
                throw CustomSegmentationError.unsupportedOutput
            }
        } else if let array = output.multiArrayConstraint {
            _ = try CustomMaskDecoder.size(of: array.shape)
            guard [.float16, .float32, .double].contains(array.dataType) else {
                throw CustomSegmentationError.unsupportedOutput
            }
        } else { throw CustomSegmentationError.unsupportedOutput }
        outputName = output.name
    }

    /// U²-Net exports its fused foreground mask plus six auxiliary training heads.
    private static func maskOutput(in description: MLModelDescription) throws -> MLFeatureDescription {
        let outputs = description.outputDescriptionsByName
        if outputs.count == 1, let output = outputs.values.first { return output }
        let u2netHeads = Set((0...6).map { "out_p\($0)" })
        guard Set(outputs.keys) == u2netHeads,
              outputs.values.allSatisfy({ $0.imageConstraint?.pixelFormatType == kCVPixelFormatType_OneComponent8 }),
              let fused = outputs["out_p0"] else { throw CustomSegmentationError.unsupportedOutput }
        return fused
    }

    /// Validate the declared interface and a real prediction before an imported model becomes active.
    static func validate(modelURL: URL) throws {
        let segmenter = try CustomForegroundSegmenter(modelURL: modelURL)
        let image = CIImage(color: .black).cropped(to: CGRect(
            x: 0, y: 0, width: segmenter.input.pixelsWide, height: segmenter.input.pixelsHigh
        ))
        _ = try segmenter.mask(for: image)
    }

    func mask(for image: CIImage) throws -> CIImage {
        let bounds = CGRect(x: 0, y: 0, width: input.pixelsWide, height: input.pixelsHigh)
        if inputBuffer == nil {
            let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
            guard CVPixelBufferCreate(kCFAllocatorDefault, input.pixelsWide, input.pixelsHigh,
                                      input.pixelFormatType, attributes, &inputBuffer) == kCVReturnSuccess else {
                throw VideoError.allocation
            }
        }
        guard let inputBuffer else { throw VideoError.allocation }
        context.render(aligned(image, to: bounds), to: inputBuffer,
                       bounds: bounds, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        let features = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: inputBuffer)])
        let prediction = try model.prediction(from: features)
        guard let output = prediction.featureValue(for: outputName) else { throw CustomSegmentationError.unsupportedOutput }
        let mask: CIImage
        if let pixels = output.imageBufferValue {
            mask = try checkedImage(pixels)
        } else if let values = output.multiArrayValue {
            mask = try CustomMaskDecoder.image(from: values)
        } else { throw CustomSegmentationError.unsupportedOutput }
        return aligned(mask, to: image.extent)
    }

    /// Stretch the full frame, clamping the boundary to avoid transparent interpolation into its edges.
    private func aligned(_ image: CIImage, to bounds: CGRect) -> CIImage {
        let extent = image.extent
        return image.clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: bounds.width / extent.width, y: bounds.height / extent.height))
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            .cropped(to: bounds)
    }

    private func checkedImage(_ buffer: CVPixelBuffer) throws -> CIImage {
        let image = CIImage(cvPixelBuffer: buffer, options: [.colorSpace: NSNull()])
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        var values = [Float](repeating: 0, count: width * height)
        context.render(image, toBitmap: &values, rowBytes: width * MemoryLayout<Float>.size,
                       bounds: image.extent, format: .Lf, colorSpace: nil)
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else { throw CustomSegmentationError.invalidMask }
        return image
    }
}
