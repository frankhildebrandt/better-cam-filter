import CoreImage
import Testing
@testable import BetterCamCore

struct FrameCompositionTests {
    @Test func squareVisionMaskKeepsNormalizedVerticalPositionInWidescreenVideo() {
        let black = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 3, width: 4, height: 1))
            .composited(over: black)
        let aligned = FrameComposition.alignMask(mask, to: CGRect(x: 0, y: 0, width: 8, height: 4))
        #expect(pixel(aligned, x: 4, y: 3) == [255, 255, 255, 255])
        #expect(pixel(aligned, x: 4, y: 1) == [0, 0, 0, 255])
    }

    @Test func maskAlignmentHandlesTranslatedOriginsAndOutputCrop() {
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 40, y: -20, width: 4, height: 4))
        let bounds = CGRect(x: 12, y: 8, width: 16, height: 9)
        let aligned = FrameComposition.alignMask(mask, to: bounds)
        #expect(aligned.extent == bounds)
        #expect(pixel(aligned, x: 12, y: 8) == [255, 255, 255, 255])
        #expect(pixel(aligned, x: 27, y: 16) == [255, 255, 255, 255])
    }

    @Test func aspectFillCropsTheCenterWithoutDistortion() {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 2))
        let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
            .cropped(to: CGRect(x: 3, y: 0, width: 2, height: 2))
        let image = green.composited(over: red)
        let bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        let result = FrameComposition.aspectFill(image, in: bounds)
        #expect(result.extent == bounds)
        #expect(pixel(result, x: 0, y: 0) == [0, 255, 0, 255])
        #expect(pixel(result, x: 1, y: 1) == [0, 255, 0, 255])
    }

    @Test func aspectFillSupportsTranslatedImages() {
        let image = CIImage(color: .white).cropped(to: CGRect(x: 40, y: -20, width: 4, height: 2))
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
        let result = FrameComposition.aspectFill(image, in: bounds)
        #expect(result.extent == bounds)
        #expect(pixel(result, x: 0, y: 0) == [255, 255, 255, 255])
    }

    @Test func segmentationMaskPreservesPersonAndReplacesBackground() {
        let bounds = CGRect(x: 0, y: 0, width: 4, height: 2)
        let foreground = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
        let background = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: bounds)
        let black = CIImage(color: .black).cropped(to: bounds)
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2))
            .composited(over: black)
        let result = FrameComposition.replaceBackground(foreground: foreground, background: background, mask: mask)
        #expect(pixel(result, x: 0, y: 0) == [255, 0, 0, 255])
        #expect(pixel(result, x: 3, y: 0) == [0, 0, 255, 255])
    }

    @Test func rearReactionsStayBehindPersonAndFrontReactionsRemainVisible() {
        let bounds = CGRect(x: 0, y: 0, width: 4, height: 2)
        let image = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
        let rear = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: bounds)
        let front = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2))
            .composited(over: CIImage(color: .black).cropped(to: bounds))
        let result = FrameComposition.compositeReactions(over: image, foreground: front,
                                                         background: rear, personMask: mask)
        #expect(pixel(result, x: 0, y: 0) == [0, 255, 0, 255])
        #expect(pixel(result, x: 1, y: 0) == [255, 0, 0, 255])
        #expect(pixel(result, x: 3, y: 0) == [0, 0, 255, 255])
        #expect(result.extent == bounds)
    }

    @Test func missingOptionalReactionMaskKeepsHealthyCameraImage() {
        let bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        let image = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
        let rear = CIImage(color: .white).cropped(to: bounds)
        let result = FrameComposition.compositeReactions(over: image, foreground: nil,
                                                         background: rear, personMask: nil)
        #expect(pixel(result, x: 1, y: 1) == [255, 0, 0, 255])
    }

    @Test func rearReactionWithReplacementBackgroundUsesSoftPersonMaskOnlyOnce() {
        let bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        let person = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
        let background = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: bounds)
        let rear = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: bounds)
        let mask = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: bounds)
        let result = FrameComposition.replaceBackground(foreground: person, background: background,
                                                        mask: mask, backgroundReaction: rear)
        var rgba = [UInt8](repeating: 0, count: 4)
        // Check blend weights directly, independent of the current display's RGB profile.
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            result, toBitmap: &rgba, rowBytes: 4, bounds: CGRect(x: 1, y: 1, width: 1, height: 1),
            format: .RGBA8, colorSpace: nil)
        #expect(abs(Int(rgba[0]) - 128) <= 1)
        #expect(rgba[1] == 0)
        #expect(abs(Int(rgba[2]) - 128) <= 1)
    }

    private func pixel(_ image: CIImage, x: Int, y: Int) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: 4)
        CIContext().render(image, toBitmap: &rgba, rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return rgba
    }
}
