import CoreImage
import CoreML

enum CustomSegmentationError: LocalizedError {
    case missingModel, unsupportedInput, unsupportedOutput, invalidMask

    var errorDescription: String? {
        switch self {
        case .missingModel: "Bitte zuerst ein Custom-Modell in der Konfiguration importieren."
        case .unsupportedInput: "Das Modell benötigt genau einen Bildeingang ohne weitere Eingaben oder Zustände."
        case .unsupportedOutput: "Das Modell muss eine Graustufenmaske oder eine Float-Alpha-Maske [H,W], [1,H,W] oder [1,1,H,W] ausgeben. Die sieben bekannten U²-Net-Ausgänge werden ebenfalls unterstützt."
        case .invalidMask: "Die Modellmaske muss endliche Vordergrundwerte zwischen 0 und 1 enthalten (1 = behalten)."
        }
    }
}

/// Decode foreground probabilities with their declared strides; tensor row zero is the image's top row.
enum CustomMaskDecoder {
    static func size(of shape: [NSNumber]) throws -> (width: Int, height: Int) {
        let dimensions = shape.map(\.intValue)
        guard (2...4).contains(dimensions.count), dimensions.dropLast(2).allSatisfy({ $0 == 1 }),
              let width = dimensions.last, width > 0, dimensions[dimensions.count - 2] > 0 else {
            throw CustomSegmentationError.unsupportedOutput
        }
        return (width, dimensions[dimensions.count - 2])
    }

    static func image(from array: MLMultiArray) throws -> CIImage {
        let size = try size(of: array.shape)
        let strides = array.strides.map(\.intValue)
        var pixels = [Float](repeating: 0, count: size.width * size.height)
        for y in 0..<size.height {
            for x in 0..<size.width {
                let index = y * strides[strides.count - 2] + x * strides[strides.count - 1]
                let value: Float
                switch array.dataType {
                case .float32: value = array.dataPointer.assumingMemoryBound(to: Float.self)[index]
                case .double: value = Float(array.dataPointer.assumingMemoryBound(to: Double.self)[index])
                case .float16: value = halfFloat(array.dataPointer.assumingMemoryBound(to: UInt16.self)[index])
                default: throw CustomSegmentationError.unsupportedOutput
                }
                guard value.isFinite, value >= 0, value <= 1 else { throw CustomSegmentationError.invalidMask }
                pixels[y * size.width + x] = value
            }
        }
        return image(topDownPixels: pixels, width: size.width, height: size.height)
    }

    static func image(topDownPixels: [Float], width: Int, height: Int) -> CIImage {
        let data = topDownPixels.withUnsafeBytes { Data($0) }
        return CIImage(bitmapData: data, bytesPerRow: width * MemoryLayout<Float>.size,
                       size: CGSize(width: width, height: height), format: .Lf, colorSpace: nil)
    }

    /// Decode IEEE binary16 on Intel as well as Apple Silicon without Swift Float16 availability.
    private static func halfFloat(_ bits: UInt16) -> Float {
        let sign = UInt32(bits & 0x8000) << 16
        let exponent = UInt32((bits >> 10) & 0x1f)
        let mantissa = UInt32(bits & 0x03ff)
        if exponent == 0 {
            let value = Float(mantissa) / 16_777_216
            return sign == 0 ? value : -value
        }
        if exponent == 31 { return Float(bitPattern: sign | 0x7f800000 | (mantissa << 13)) }
        return Float(bitPattern: sign | ((exponent + 112) << 23) | (mantissa << 13))
    }
}
