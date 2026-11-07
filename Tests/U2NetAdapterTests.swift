import CoreImage
import CoreML
import Testing
@testable import BetterCamCore

struct U2NetAdapterTests {
    @Test func selectsTheFusedHeadRatherThanAnAuxiliaryMask() throws {
        let fixture = try make(heads: 7)
        defer { fixture.remove() }
        let segmenter = try CustomForegroundSegmenter(modelURL: fixture.compiled)
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 16, height: 9))
        let mask = try segmenter.mask(for: image)
        var value: Float = 0
        CIContext().render(mask, toBitmap: &value, rowBytes: 4,
                           bounds: CGRect(x: 8, y: 4, width: 1, height: 1), format: .Lf, colorSpace: nil)
        #expect(value > 0.99)
    }

    @Test func incompleteAuxiliaryOutputFamilyIsRejected() throws {
        let fixture = try make(heads: 6)
        defer { fixture.remove() }
        #expect(throws: CustomSegmentationError.self) {
            try CustomForegroundSegmenter(modelURL: fixture.compiled)
        }
    }

    /// Synthetic Core ML graph: the fused head is white; every auxiliary head is black.
    private func make(heads: Int) throws -> CustomModelFixture {
        let complete = "CAQSnwEKEQoFaW1hZ2UaCCIGCAQQBBgKUhIKBm91dF9wMBoIIgYIBBAEGApSEgoGb3V0X3AxGggiBggEEAQYClISCgZvdXRfcDIaCCIGCAQQBBgKUhIKBm91dF9wMxoIIgYIBBAEGApSEgoGb3V0X3A0GggiBggEEAQYClISCgZvdXRfcDUaCCIGCAQQBBgKUhIKBm91dF9wNhoIIgYIBBAEGAqiH+4BCiAKBWhlYWQwEgVpbWFnZRoGb3V0X3AwkggHKgUNAACAPwogCgVoZWFkMRIFaW1hZ2UaBm91dF9wMZIIByoFDQAAAAAKIAoFaGVhZDISBWltYWdlGgZvdXRfcDKSCAcqBQ0AAAAACiAKBWhlYWQzEgVpbWFnZRoGb3V0X3AzkggHKgUNAAAAAAogCgVoZWFkNBIFaW1hZ2UaBm91dF9wNJIIByoFDQAAAAAKIAoFaGVhZDUSBWltYWdlGgZvdXRfcDWSCAcqBQ0AAAAACiAKBWhlYWQ2EgVpbWFnZRoGb3V0X3A2kggHKgUNAAAAAA=="
        let incomplete = "CAQSiwEKEQoFaW1hZ2UaCCIGCAQQBBgKUhIKBm91dF9wMBoIIgYIBBAEGApSEgoGb3V0X3AxGggiBggEEAQYClISCgZvdXRfcDIaCCIGCAQQBBgKUhIKBm91dF9wMxoIIgYIBBAEGApSEgoGb3V0X3A0GggiBggEEAQYClISCgZvdXRfcDUaCCIGCAQQBBgKoh/MAQogCgVoZWFkMBIFaW1hZ2UaBm91dF9wMJIIByoFDQAAgD8KIAoFaGVhZDESBWltYWdlGgZvdXRfcDGSCAcqBQ0AAAAACiAKBWhlYWQyEgVpbWFnZRoGb3V0X3AykggHKgUNAAAAAAogCgVoZWFkMxIFaW1hZ2UaBm91dF9wM5IIByoFDQAAAAAKIAoFaGVhZDQSBWltYWdlGgZvdXRfcDSSCAcqBQ0AAAAACiAKBWhlYWQ1EgVpbWFnZRoGb3V0X3A1kggHKgUNAAAAAA=="
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("SyntheticHeads.mlmodel")
        try Data(base64Encoded: heads == 7 ? complete : incomplete)!.write(to: source)
        do {
            return try CustomModelFixture(directory: directory, source: source, compiled: MLModel.compileModel(at: source))
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
