import CoreImage
import Testing
@testable import BetterCamCore

struct AccessoryMaskRefinerTests {
    @Test func noEligibleAccessoryLeavesSoftSemanticEdgesUnchanged() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        let image = CIImage(color: .white).cropped(to: bounds)
        let mask = CIImage.empty().applyingFilter("CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: 160, y: 90), "inputRadius0": 24, "inputRadius1": 72,
            "inputColor0": CIColor.white, "inputColor1": CIColor.black
        ]).cropped(to: bounds)
        let result = AccessoryMaskRefiner().refine(mask: mask, image: image)
        #expect(pixels(result, in: bounds) == pixels(mask, in: bounds))
    }

    @Test func imageReadbackKeepsBottomAccessoryAndRejectsTopWall() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        let white = CIImage(color: .white).cropped(to: bounds)
        let body = CGRect(x: 140, y: 0, width: 40, height: 110)
        let bottomAccessory = CGRect(x: 181, y: 0, width: 24, height: 70)
        let topWall = CGRect(x: 115, y: 0, width: 24, height: 180)
        let dark = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1))
        let image = [body, bottomAccessory, topWall].reduce(white) { partial, rect in
            dark.cropped(to: rect).composited(over: partial)
        }
        let mask = CIImage(color: .white).cropped(to: body)
            .composited(over: CIImage(color: .black).cropped(to: bounds))
        let result = AccessoryMaskRefiner().refine(mask: mask, image: image)
        #expect(pixels(result, in: CGRect(x: 192, y: 30, width: 1, height: 1))[0] > 240)
        #expect(pixels(result, in: CGRect(x: 126, y: 160, width: 1, height: 1))[0] == 0)
    }

    private func pixels(_ image: CIImage, in bounds: CGRect) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(bounds.width * bounds.height) * 4)
        CIContext().render(image, toBitmap: &bytes, rowBytes: Int(bounds.width) * 4,
                           bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
