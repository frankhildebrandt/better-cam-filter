import CoreImage
import Testing
@testable import BetterCamCore

struct KeepMaskTests {
    @Test func strokesKeepTopLeftPreviewCoordinatesInCoreImage() throws {
        let stroke = KeepStroke(points: [CGPoint(x: 0.25, y: 0.25)], radius: 0.03)
        let bitmap = try #require(KeepMask.render([stroke], width: 200, height: 100))
        let mask = CIImage(cgImage: bitmap)
        #expect(pixel(mask, x: 50, y: 75) == [255, 255, 255, 255])
        #expect(pixel(mask, x: 50, y: 25) == [0, 0, 0, 255])
    }

    @Test func continuousStrokePreservesObjectsBetweenPointerSamples() throws {
        let stroke = KeepStroke(points: [CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.8)], radius: 0.02)
        let bitmap = try #require(KeepMask.render([stroke], width: 200, height: 100))
        let mask = CIImage(cgImage: bitmap)
        let automatic = CIImage(color: .black).cropped(to: mask.extent)
        let combined = FrameComposition.preserving(mask, in: automatic)
        let foreground = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: mask.extent)
        let background = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: mask.extent)
        let result = FrameComposition.replaceBackground(foreground: foreground, background: background, mask: combined)
        #expect(pixel(result, x: 100, y: 20) == [255, 0, 0, 255])
        #expect(pixel(result, x: 100, y: 80) == [0, 0, 255, 255])
    }

    @Test func clearingStrokesRemovesTheOverride() {
        #expect(KeepMask.render([]) == nil)
        let automatic = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 4))
        #expect(pixel(FrameComposition.preserving(nil, in: automatic), x: 4, y: 2) == [0, 0, 0, 255])
    }

    private func pixel(_ image: CIImage, x: Int, y: Int) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: 4)
        CIContext().render(image, toBitmap: &rgba, rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return rgba
    }
}
