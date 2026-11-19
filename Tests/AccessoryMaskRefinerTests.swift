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

    @Test func tallMicCapsuleStaysOpaqueAsVisionAlternatesAboveTheTorso() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        let body = CGRect(x: 140, y: 0, width: 75, height: 150)
        let microphone = CGRect(x: 125, y: 10, width: 12, height: 114)
        let room = CIImage(color: .white).cropped(to: bounds)
        let dark = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1))
        let image = dark.cropped(to: microphone).composited(over: dark.cropped(to: body).composited(over: room))
        let person = CIImage(color: .white).cropped(to: body).composited(over: CIImage(color: .black).cropped(to: bounds))
        let covered = CIImage(color: .white).cropped(to: microphone).composited(over: person)
        let refiner = AccessoryMaskRefiner(context: context)
        for frame in 0..<16 {
            let semantic = frame < 6 || !frame.isMultiple(of: 2) ? covered : person
            let mask = refiner.refine(mask: semantic, image: image, time: Double(frame) / 30)
            #expect(pixels(mask, in: CGRect(x: 131, y: 112, width: 1, height: 1))[0] > 240)
            #expect(pixels(mask, in: CGRect(x: 116, y: 112, width: 1, height: 1))[0] == 0)
        }
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

    @Test func connectedBoomPlugAndThinCableStayVisibleWithOpenGaps() {
        let bounds = CGRect(x: 0, y: 0, width: 1280, height: 720)
        // Design the fixture in camera coordinates and render it at four times
        // that size so the normal mask upsampling path is exercised as well.
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGRect {
            CGRect(x: x * 4, y: y * 4, width: w * 4, height: h * 4)
        }
        let body = rect(236, 5, 42, 145)
        let room = CIImage(color: .white).cropped(to: bounds)
        let personOnly = room.cropped(to: body).composited(over: CIImage(color: .black).cropped(to: bounds))
        var image = CIImage(color: .gray).cropped(to: body).composited(over: room)
        let rails = [rect(145, 38, 91, 3), rect(145, 52, 91, 3), rect(232, 38, 4, 17),
                     rect(145, 38, 5, 17), rect(135, 42, 11, 10)]
        let plug = rect(123, 43, 13, 7)
        let cable = rect(50, 46, 73, 1)
        for part in rails + [cable] {
            image = CIImage(color: .black).cropped(to: part).composited(over: image)
        }
        image = CIImage(color: .gray).cropped(to: plug).composited(over: image)
        image = room.cropped(to: rect(125, 44, 8, 5)).composited(over: image)
        let covered = room.cropped(to: cable).composited(over: personOnly)
        let refiner = AccessoryMaskRefiner(context: context)
        for frame in 0..<10 {
            let mask = refiner.refine(mask: frame < 5 || !frame.isMultiple(of: 2) ? covered : personOnly,
                                      image: image, time: Double(frame) / 30)
            guard frame >= 5 else { continue }
            for (x, y) in [(200, 39), (200, 53), (140, 46), (129, 46), (75, 46)] {
                let pixel = CGRect(x: x * 4 + 2, y: y * 4 + 2, width: 1, height: 1)
                #expect(pixels(mask, in: pixel)[0] > 220)
            }
            for (x, y) in [(200, 46), (75, 50), (75, 42)] {
                #expect(pixels(mask, in: CGRect(x: x * 4, y: y * 4, width: 1, height: 1))[0] < 15)
            }
        }
    }

    @Test func highDetailRecoversATwoPixelCableInAFullSizeFrame() {
        let bounds = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let body = CGRect(x: 1200, y: 0, width: 400, height: 820)
        let cable = CGRect(x: 500, y: 320, width: 700, height: 2)
        let white = CIImage(color: .white).cropped(to: bounds)
        let black = CIImage(color: .black).cropped(to: bounds)
        let image = black.cropped(to: cable).composited(over: CIImage(color: .gray).cropped(to: body).composited(over: white))
        let person = white.cropped(to: body).composited(over: black)
        func settledMask(_ detail: AccessoryDetail) -> CIImage {
            let refiner = AccessoryMaskRefiner(context: context)
            var mask = person
            for frame in 0..<6 {
                mask = refiner.refine(mask: person, image: image, time: Double(frame) / 30, detail: detail)
            }
            return mask
        }
        let standard = settledMask(.standard), fine = settledMask(.veryFine)
        for x in [550, 850, 1140] {
            let center = CGRect(x: x, y: 320, width: 1, height: 1)
            #expect(pixels(fine, in: center)[0] > 220)
            #expect(pixels(standard, in: center)[0] < 60)
            #expect(pixels(fine, in: center.offsetBy(dx: 0, dy: 5))[0] < 15)
        }
    }

    private func pixels(_ image: CIImage, in bounds: CGRect) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(bounds.width * bounds.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(bounds.width) * 4,
                       bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
