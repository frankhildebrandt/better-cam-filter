import CoreImage
import Testing
@testable import BetterCamCore

struct AccessoryMaskRefinerTests {
    private let context = CIContext()
    @Test func stationaryMicRemainsOpaqueWhenVisionChangesItsSemanticOwnership() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        let body = CGRect(x: 140, y: 0, width: 40, height: 110)
        let microphone = CGRect(x: 115, y: 0, width: 24, height: 60)
        let white = CIImage(color: .white).cropped(to: bounds)
        let black = CIImage(color: .black).cropped(to: bounds)
        let dark = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1))
        let image = dark.cropped(to: microphone).composited(over: dark.cropped(to: body).composited(over: white))
        let personOnly = CIImage(color: .white).cropped(to: body).composited(over: black)
        let personAndMic = CIImage(color: .white).cropped(to: microphone).composited(over: personOnly)
        let refiner = AccessoryMaskRefiner()
        for frame in 0..<6 {
            _ = refiner.refine(mask: personAndMic, image: image, time: Double(frame) * 0.04)
        }
        for frame in 6..<16 {
            let semantic = frame.isMultiple(of: 2) ? personOnly : personAndMic
            let result = refiner.refine(mask: semantic, image: image, time: Double(frame) * 0.04)
            #expect(pixels(result, in: CGRect(x: 126, y: 30, width: 1, height: 1))[0] > 240)
        }
    }

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

    @Test func movingMicRetainsItsLeadingEdgeWithoutAnotherStartupDelay() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        let body = CGRect(x: 140, y: 0, width: 40, height: 110)
        let microphone = CGRect(x: 115, y: 0, width: 24, height: 60)
        let white = CIImage(color: .white).cropped(to: bounds)
        let dark = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1))
        let roomAndBody = dark.cropped(to: body).composited(over: white)
        let person = CIImage(color: .white).cropped(to: body)
            .composited(over: CIImage(color: .black).cropped(to: bounds))
        let refiner = AccessoryMaskRefiner()
        for frame in 0..<6 {
            let image = dark.cropped(to: microphone).composited(over: roomAndBody)
            _ = refiner.refine(mask: person, image: image, time: Double(frame) * 0.04)
        }
        let movedImage = dark.cropped(to: microphone.offsetBy(dx: -4, dy: 0)).composited(over: roomAndBody)
        let result = refiner.refine(mask: person, image: movedImage, time: 0.24)
        #expect(pixels(result, in: CGRect(x: 113, y: 30, width: 1, height: 1))[0] > 240)
        #expect(pixels(result, in: CGRect(x: 95, y: 30, width: 1, height: 1))[0] == 0)
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
        let refiner = AccessoryMaskRefiner()
        var result = mask
        for frame in 0..<5 { result = refiner.refine(mask: mask, image: image, time: Double(frame) / 30) }
        #expect(pixels(result, in: CGRect(x: 192, y: 30, width: 1, height: 1))[0] > 240)
        #expect(pixels(result, in: CGRect(x: 126, y: 160, width: 1, height: 1))[0] == 0)
    }

    private func pixels(_ image: CIImage, in bounds: CGRect) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(bounds.width * bounds.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(bounds.width) * 4,
                       bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
