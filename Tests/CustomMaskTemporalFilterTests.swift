import CoreImage
import Testing
@testable import BetterCamCore

struct CustomMaskTemporalFilterTests {
    private let context = CIContext()
    private let bounds = CGRect(x: 0, y: 0, width: 32, height: 18)
    private let microphone = CGRect(x: 10, y: 3, width: 6, height: 12)

    @Test func stableMicrophoneSurvivesOnlyABoundedDropout() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        for time in [0.03, 0.07, 0.11] {
            let held = filter.filter(mask: black(), image: appearance(), time: time, strength: 1)
            #expect(value(held, x: 12, y: 8) > 0.99)
            #expect(value(held, x: 2, y: 8) == 0)
        }
        let expired = filter.filter(mask: black(), image: appearance(), time: 0.16, strength: 1)
        #expect(value(expired, x: 12, y: 8) == 0)
        let stillMissing = filter.filter(mask: black(), image: appearance(), time: 0.20, strength: 1)
        #expect(value(stillMissing, x: 12, y: 8) == 0)
    }

    @Test func newForegroundAndPositiveRecoveryNeverWaitForConfirmation() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: black(), image: appearance(), time: 0, strength: 1)
        let entering = filter.filter(mask: micMask(), image: appearance(), time: 0.03, strength: 1)
        #expect(value(entering, x: 12, y: 8) > 0.99)
        _ = filter.filter(mask: black(), image: appearance(), time: 0.06, strength: 1)
        let recovered = filter.filter(mask: micMask(), image: appearance(), time: 0.09, strength: 1)
        #expect(value(recovered, x: 12, y: 8) > 0.99)
    }

    @Test func changedSourcePixelsReleaseHistoryImmediately() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let revealedRoom = CIImage(color: .white).cropped(to: bounds)
        let result = filter.filter(mask: black(), image: revealedRoom, time: 0.03, strength: 1)
        #expect(value(result, x: 12, y: 8) == 0)
    }

    @Test func movingObjectHasNoOldSilhouetteTrail() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let moved = microphone.offsetBy(dx: 10, dy: 0)
        let mask = CIImage(color: .white).cropped(to: moved).composited(over: black())
        let image = CIImage(color: .black).cropped(to: moved)
            .composited(over: CIImage(color: .white).cropped(to: bounds))
        let result = filter.filter(mask: mask, image: image, time: 0.03, strength: 1)
        #expect(value(result, x: 12, y: 8) == 0)
        #expect(value(result, x: 22, y: 8) > 0.99)
    }

    @Test func strengthZeroIsAnExactBypassAndClearsHistory() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let soft = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3)).cropped(to: bounds)
        let unchanged = filter.filter(mask: soft, image: appearance(), time: 0.03, strength: 0)
        #expect(value(unchanged, x: 12, y: 8) == value(soft, x: 12, y: 8))
        let afterEnable = filter.filter(mask: black(), image: appearance(), time: 0.06, strength: 1)
        #expect(value(afterEnable, x: 12, y: 8) == 0)
    }

    @Test(arguments: [-0.1, 0.5, Double.nan])
    func timeDiscontinuitiesDoNotKeepAnOldMicrophone(nextTime: Double) {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let result = filter.filter(mask: black(), image: appearance(), time: nextTime, strength: 1)
        #expect(value(result, x: 12, y: 8) == 0)
    }

    @Test func changedStrengthAndSourceExtentResetHistory() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let changedSetting = filter.filter(mask: black(), image: appearance(), time: 0.03, strength: 0.5)
        #expect(value(changedSetting, x: 12, y: 8) == 0)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0.06, strength: 1)
        let shifted = appearance().transformed(by: CGAffineTransform(translationX: 1, y: 0))
        let movedSource = filter.filter(mask: black(), image: shifted, time: 0.09, strength: 1)
        #expect(value(movedSource, x: 12, y: 8) == 0)
    }

    @Test func translatedOutputCoordinatesStayAligned() {
        let filter = CustomMaskTemporalFilter(context: context)
        let shift = CGAffineTransform(translationX: 70, y: 30)
        let first = micMask().transformed(by: shift)
        let image = appearance().transformed(by: shift)
        _ = filter.filter(mask: first, image: image, time: 0, strength: 1)
        let mask = black().transformed(by: shift)
        let held = filter.filter(mask: mask, image: image, time: 0.03, strength: 1)
        #expect(held.extent == mask.extent)
        #expect(value(held, x: 82, y: 38) > 0.99)
        #expect(value(held, x: 72, y: 38) == 0)
    }

    @Test func aBackgroundNeverPredictedAsForegroundCannotAccumulateHistory() {
        let filter = CustomMaskTemporalFilter(context: context)
        for frame in 0..<10 {
            let result = filter.filter(mask: black(), image: appearance(), time: Double(frame) * 0.03, strength: 1)
            #expect(value(result, x: 12, y: 8) == 0)
        }
    }

    @Test func sourceDimensionChangeCannotReuseOldCoordinates() {
        let filter = CustomMaskTemporalFilter(context: context)
        _ = filter.filter(mask: micMask(), image: appearance(), time: 0, strength: 1)
        let larger = CGRect(x: 0, y: 0, width: 48, height: 27)
        let image = CIImage(color: .black).cropped(to: microphone)
            .composited(over: CIImage(color: .white).cropped(to: larger))
        let result = filter.filter(mask: CIImage(color: .black).cropped(to: larger), image: image,
                                   time: 0.03, strength: 1)
        #expect(result.extent == larger)
        #expect(value(result, x: 12, y: 8) == 0)
    }

    @Test func fullHDReadbackKeepsTheSameMicrophoneCoordinates() {
        let filter = CustomMaskTemporalFilter(context: context)
        let fullHD = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let microphone = CGRect(x: 600, y: 300, width: 240, height: 480)
        let black = CIImage(color: .black).cropped(to: fullHD)
        let mask = CIImage(color: .white).cropped(to: microphone).composited(over: black)
        let image = CIImage(color: .black).cropped(to: microphone)
            .composited(over: CIImage(color: .white).cropped(to: fullHD))
        _ = filter.filter(mask: mask, image: image, time: 0, strength: 1)
        let held = filter.filter(mask: black, image: image, time: 0.03, strength: 1)
        #expect(held.extent == fullHD)
        #expect(value(held, x: 720, y: 540) > 0.99)
        #expect(value(held, x: 300, y: 540) == 0)
    }

    private func black() -> CIImage { CIImage(color: .black).cropped(to: bounds) }
    private func micMask() -> CIImage { CIImage(color: .white).cropped(to: microphone).composited(over: black()) }
    private func appearance() -> CIImage {
        CIImage(color: .black).cropped(to: microphone)
            .composited(over: CIImage(color: .white).cropped(to: bounds))
    }
    private func value(_ image: CIImage, x: Int, y: Int) -> Float {
        var result: Float = -1
        context.render(image, toBitmap: &result, rowBytes: 4,
                       bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .Lf, colorSpace: nil)
        return result
    }
}
