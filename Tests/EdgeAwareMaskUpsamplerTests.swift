import CoreImage
import Foundation
import Testing
@testable import BetterCamCore

struct EdgeAwareMaskUpsamplerTests {
    private let context = CIContext(options: [.workingColorSpace: NSNull()])

    @Test func edgeFollowsTheFullResolutionFrameInsteadOfALinearRamp() {
        let guide = halves(CGRect(x: 0, y: 0, width: 64, height: 32))
        let mask = bitmapHalves(width: 16, height: 16)
        let linear = FrameComposition.alignMask(mask, to: guide.extent)
        let upsampled = EdgeAwareMaskUpsampler.upsample(mask, guide: guide)
        #expect(value(linear, x: 31, y: 16) > 64) // The old stretch blurs across several pixels.
        #expect(value(upsampled, x: 31, y: 16) < 16)
        #expect(value(upsampled, x: 32, y: 16) > 240)
    }

    @Test func outputCoversTheGuideEvenWhenBothHaveOffsetOrigins() {
        let guide = halves(CGRect(x: 100, y: 40, width: 64, height: 32))
        let mask = bitmapHalves(width: 16, height: 16).transformed(by: CGAffineTransform(translationX: -7, y: 3))
        let upsampled = EdgeAwareMaskUpsampler.upsample(mask, guide: guide)
        #expect(upsampled.extent == guide.extent)
        #expect(value(upsampled, x: 110, y: 50) < 16)
        #expect(value(upsampled, x: 150, y: 50) > 240)
    }

    @Test func masksAtLeastAsLargeAsTheFrameAreOnlyAligned() {
        let guide = halves(CGRect(x: 0, y: 0, width: 16, height: 8))
        let mask = bitmapHalves(width: 32, height: 16)
        let upsampled = EdgeAwareMaskUpsampler.upsample(mask, guide: guide)
        #expect(upsampled.extent == guide.extent)
        #expect(value(upsampled, x: 4, y: 4) == 0)
        #expect(value(upsampled, x: 12, y: 4) == 255)
    }

    /// Black left half, white right half.
    private func halves(_ bounds: CGRect) -> CIImage {
        CIImage(color: .white).cropped(to: CGRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height))
            .composited(over: CIImage(color: .black).cropped(to: bounds))
    }

    /// A real pixel mask like Vision's output; Core Image keeps constant-color crops geometrically exact.
    private func bitmapHalves(width: Int, height: Int) -> CIImage {
        let pixels = (0..<width * height).map { $0 % width < width / 2 ? UInt8(0) : 255 }
        return CIImage(bitmapData: Data(pixels), bytesPerRow: width, size: CGSize(width: width, height: height),
                       format: .L8, colorSpace: nil)
    }

    private func value(_ image: CIImage, x: Int, y: Int) -> UInt8 {
        var rgba = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &rgba, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return rgba[0]
    }
}
