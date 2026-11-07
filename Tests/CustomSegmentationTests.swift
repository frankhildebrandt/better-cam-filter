import CoreImage
import CoreML
import Testing
@testable import BetterCamCore

struct CustomSegmentationTests {
    @Test func configuredPostprocessingChangesTheActualRouterMaskAndCanBeBypassed() throws {
        let fixture = try CustomModelFixture.make(imageOutput: true)
        defer { fixture.remove() }
        let bytes = Data(repeating: 128, count: 16)
        let image = CIImage(bitmapData: bytes, bytesPerRow: 4, size: CGSize(width: 4, height: 4),
                            format: .L8, colorSpace: nil)
        let segmenter = ForegroundSegmenter()
        var configuration = SegmentationConfiguration(provider: .custom, customModelURL: fixture.compiled)
        configuration.maskSettings = .original
        segmenter.configuration = configuration
        let raw = value(try segmenter.mask(for: image, time: 0), x: 2, y: 2)
        #expect(raw > 0.15 && raw < 0.85)

        configuration.maskSettings = CustomMaskSettings(threshold: Double(raw) - 0.1, transition: 0.04,
                                                        edgeInset: 0, temporalStrength: 0)
        segmenter.configuration = configuration
        #expect(value(try segmenter.mask(for: image, time: 0.04), x: 2, y: 2) > 0.99)
        configuration.maskSettings.threshold = Double(raw) + 0.1
        segmenter.configuration = configuration
        #expect(value(try segmenter.mask(for: image, time: 0.08), x: 2, y: 2) < 0.01)
        configuration.maskSettings = .original
        segmenter.configuration = configuration
        #expect(abs(value(try segmenter.mask(for: image, time: 0.12), x: 2, y: 2) - raw) < 0.001)
    }

    @Test func customModelActuallyPredictsAndPreservesWholeImageCoordinates() throws {
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        try CustomForegroundSegmenter.validate(modelURL: fixture.compiled)
        let segmenter = ForegroundSegmenter()
        segmenter.configuration = SegmentationConfiguration(provider: .custom,
            customModelURL: fixture.compiled, customModelName: "Test alpha")
        let bounds = CGRect(x: 13, y: 17, width: 40, height: 20)
        let image = CIImage(color: .white).cropped(to: CGRect(x: 13, y: 27, width: 20, height: 10))
            .composited(over: CIImage(color: .black).cropped(to: bounds))
        for _ in 0..<2 {
            let mask = try segmenter.mask(for: image)
            #expect(mask.extent == bounds)
            #expect(value(mask, x: 18, y: 34) > 0.90)
            #expect(value(mask, x: 18, y: 19) < 0.05)
            #expect(value(mask, x: 48, y: 34) < 0.05)
            segmenter.reset()
            segmenter.configuration.provider = .apple
            segmenter.configuration.provider = .custom
        }
    }

    @Test func unsupportedRealModelInterfacesAreRejectedBeforeActivation() throws {
        for kind in CustomModelFixture.Unsupported.allCases {
            let fixture = try CustomModelFixture.make(unsupported: kind)
            defer { fixture.remove() }
            #expect(throws: CustomSegmentationError.self) {
                try CustomForegroundSegmenter.validate(modelURL: fixture.compiled)
            }
        }
    }

    @Test func changingModelURLDoesNotReuseThePreviouslyLoadedModel() throws {
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let segmenter = ForegroundSegmenter()
        segmenter.configuration = SegmentationConfiguration(provider: .custom, customModelURL: fixture.compiled)
        let image = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        _ = try segmenter.mask(for: image)
        segmenter.configuration.customModelURL = fixture.directory.appendingPathComponent("Missing.mlmodelc")
        #expect(throws: (any Error).self) { try segmenter.mask(for: image) }
    }

    @Test func grayscaleImageOutputUsesTheSameCoordinates() throws {
        let fixture = try CustomModelFixture.make(imageOutput: true)
        defer { fixture.remove() }
        try CustomForegroundSegmenter.validate(modelURL: fixture.compiled)
        let segmenter = try CustomForegroundSegmenter(modelURL: fixture.compiled)
        let bounds = CGRect(x: 0, y: 0, width: 40, height: 20)
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 10, width: 20, height: 10))
            .composited(over: CIImage(color: .black).cropped(to: bounds))
        let mask = try segmenter.mask(for: image)
        #expect(value(mask, x: 5, y: 17) > 0.90)
        #expect(value(mask, x: 5, y: 2) < 0.05)
        #expect(value(mask, x: 35, y: 17) < 0.05)
    }

    @Test func tensorStridesAndTopDownOrientationAreRespected() throws {
        let storage = UnsafeMutablePointer<Float>.allocate(capacity: 16)
        storage.initialize(repeating: 0.8, count: 16)
        defer { storage.deinitialize(count: 16); storage.deallocate() }
        let array = try MLMultiArray(dataPointer: storage, shape: [1, 2, 3], dataType: .float32,
                                    strides: [16, 8, 2], deallocator: nil)
        array[[0, 0, 0]] = 1
        array[[0, 0, 1]] = 0.5
        array[[0, 0, 2]] = 0
        array[[0, 1, 0]] = 0
        array[[0, 1, 1]] = 0.25
        array[[0, 1, 2]] = 1
        let image = try CustomMaskDecoder.image(from: array)
        #expect(value(image, x: 0, y: 1) == 1)
        #expect(value(image, x: 1, y: 1) == 0.5)
        #expect(value(image, x: 1, y: 0) == 0.25)
    }

    @Test func invalidProbabilitiesAndClassChannelsAreRejected() throws {
        let array = try MLMultiArray(shape: [2, 2], dataType: .float32)
        for index in 0..<array.count { array[index] = 0 }
        for invalid in [Float.nan, .infinity, -0.01, 1.01] {
            array[0] = NSNumber(value: invalid)
            #expect(throws: CustomSegmentationError.self) { try CustomMaskDecoder.image(from: array) }
        }
        #expect(throws: CustomSegmentationError.self) { try CustomMaskDecoder.size(of: [1, 2, 3, 4]) }
        #expect(throws: CustomSegmentationError.self) { try CustomMaskDecoder.size(of: [1, 0, 4]) }
    }

    @Test func halfPrecisionOutputDecodesWithoutAnArchitectureSpecificFloatType() throws {
        let array = try MLMultiArray(shape: [2, 2], dataType: .float16)
        let values = array.dataPointer.assumingMemoryBound(to: UInt16.self)
        for (index, bits) in [UInt16(0), 0x3800, 0x3c00, 0x3400].enumerated() { values[index] = bits }
        let image = try CustomMaskDecoder.image(from: array)
        #expect(value(image, x: 0, y: 1) == 0)
        #expect(value(image, x: 1, y: 1) == 0.5)
        #expect(value(image, x: 0, y: 0) == 1)
        #expect(value(image, x: 1, y: 0) == 0.25)
    }

    @Test func missingCustomModelNeverFallsBackToApple() {
        let segmenter = ForegroundSegmenter()
        segmenter.configuration = SegmentationConfiguration(provider: .custom)
        let image = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        #expect(throws: CustomSegmentationError.self) { try segmenter.mask(for: image) }
    }

    private func value(_ image: CIImage, x: Int, y: Int) -> Float {
        var result: Float = -1
        CIContext().render(image, toBitmap: &result, rowBytes: MemoryLayout<Float>.size,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .Lf, colorSpace: nil)
        return result
    }
}

/// Tiny real Core ML neural network: a 4x4 grayscale image becomes its own alpha mask.
/// Encoded from Apple's public Core ML protobuf format; no training weights or third-party assets.
struct CustomModelFixture {
    let directory: URL
    let source: URL
    let compiled: URL

    enum Unsupported: CaseIterable { case tensorInput, colorOutput, classChannels }

    static func make(imageOutput: Bool = false, unsupported: Unsupported? = nil) throws -> Self {
        let array = "CAESKgoRCgVpbWFnZRoIIgYIBBAEGApSFQoFYWxwaGEaDCoKCAEIBAgEEKCABKIfKgooCg5pZGVudGl0eV9hbHBoYRIFaW1hZ2UaBWFscGhhkggHKgUNgYCAOw=="
        let image = "CAESJgoRCgVpbWFnZRoIIgYIBBAEGApSEQoFYWxwaGEaCCIGCAQQBBgKoh8qCigKDmlkZW50aXR5X2FscGhhEgVpbWFnZRoFYWxwaGGSCAcqBQ0AAIA/"
        let data: String
        switch unsupported {
        case .tensorInput:
            data = "CAESLgoVCgVpbWFnZRoMKgoIAQgECAQQoIAEUhUKBWFscGhhGgwqCggBCAQIBBCggASiHyoKKAoOaWRlbnRpdHlfYWxwaGESBWltYWdlGgVhbHBoYZIIByoFDQAAgD8="
        case .colorOutput:
            data = "CAESJgoRCgVpbWFnZRoIIgYIBBAEGBRSEQoFYWxwaGEaCCIGCAQQBBgUoh8qCigKDmlkZW50aXR5X2FscGhhEgVpbWFnZRoFYWxwaGGSCAcqBQ0AAIA/"
        case .classChannels:
            data = "CAESKgoRCgVpbWFnZRoIIgYIBBAEGBRSFQoFYWxwaGEaDCoKCAMIBAgEEKCABKIfKgooCg5pZGVudGl0eV9hbHBoYRIFaW1hZ2UaBWFscGhhkggHKgUNgYCAOw=="
        case nil: data = imageOutput ? image : array
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("IdentityAlpha-\(directory.lastPathComponent).mlmodel")
        try Data(base64Encoded: data)!.write(to: source)
        do { return try Self(directory: directory, source: source, compiled: MLModel.compileModel(at: source)) }
        catch { try? FileManager.default.removeItem(at: directory); throw error }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(at: compiled)
    }
}
