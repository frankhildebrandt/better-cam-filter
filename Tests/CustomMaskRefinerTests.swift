import CoreImage
import Foundation
import Testing
@testable import BetterCamCore

struct CustomMaskRefinerTests {
    private let context = CIContext()
    private let refiner = CustomMaskRefiner()

    @Test func confidentForegroundBecomesOpaqueAndWeakBackgroundDisappears() {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 4)
        let background = solid(0.2, in: bounds)
        let mask = solid(0.6, in: CGRect(x: 4, y: 0, width: 4, height: 4)).composited(over: background)
        var settings = CustomMaskSettings.balanced
        settings.edgeInset = 0
        let result = refiner.refine(mask, settings: settings)
        #expect(value(result, x: 1, y: 2) < 0.001)
        #expect(value(result, x: 6, y: 2) > 0.999)
    }

    @Test func detailPresetRetainsAnUncertainArmThatBalancedSettingsDoNotFullyKeep() {
        let mask = solid(0.42, in: CGRect(x: 0, y: 0, width: 16, height: 9))
        #expect(value(refiner.refine(mask, settings: .balanced), x: 8, y: 4) < 0.5)
        #expect(value(refiner.refine(mask, settings: .detailed), x: 8, y: 4) > 0.99)
    }

    @Test func originalBypassesThresholdAndMorphologyWithoutChangingProbabilities() {
        let bounds = CGRect(x: 13, y: -7, width: 8, height: 4)
        let mask = solid(0.42, in: bounds)
        let result = refiner.refine(mask, settings: .original)
        #expect(result.extent == bounds)
        #expect(abs(value(result, x: 17, y: -5) - 0.42) < 0.001)
    }

    @Test func positiveInsetShrinksTheSilhouetteAndNegativeInsetExpandsIt() {
        let bounds = CGRect(x: 0, y: 0, width: 24, height: 1080)
        let mask = solid(1, in: CGRect(x: 6, y: 0, width: 12, height: 1080))
            .composited(over: solid(0, in: bounds))
        var settings = CustomMaskSettings.balanced
        settings.edgeInset = 2
        let contracted = refiner.refine(mask, settings: settings)
        #expect(value(contracted, x: 6, y: 540) < 0.01)
        #expect(value(contracted, x: 10, y: 540) > 0.99)
        settings.edgeInset = -2
        let expanded = refiner.refine(mask, settings: settings)
        #expect(value(expanded, x: 4, y: 540) > 0.99)
        #expect(value(expanded, x: 1, y: 540) < 0.01)
        #expect(expanded.extent == bounds)
    }

    @Test func insetScalesWithResolutionAndPreservesTranslatedCoordinates() {
        let bounds = CGRect(x: 19, y: -11, width: 24, height: 540)
        let mask = solid(1, in: CGRect(x: 25, y: -11, width: 12, height: 540))
            .composited(over: solid(0, in: bounds))
        let result = refiner.refine(mask, settings: CustomMaskSettings(edgeInset: 4))
        #expect(result.extent == bounds)
        #expect(value(result, x: 25, y: 200) < 0.01)
        #expect(value(result, x: 29, y: 200) > 0.99)
    }

    @Test func missingSettingsKeysLoadDefaultsAndRoundTripEveryControl() throws {
        let missing = try JSONDecoder().decode(CustomMaskSettings.self, from: Data("{}".utf8))
        #expect(missing == .balanced)
        let settings = CustomMaskSettings(enabled: false, threshold: 0.3, transition: 0.1,
                                          edgeInset: -2, temporalStrength: 0.8, personSupport: true)
        #expect(try JSONDecoder().decode(CustomMaskSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func invalidValuesCannotProduceNaNOrUnboundedMorphology() {
        var settings = CustomMaskSettings()
        settings.threshold = .nan
        settings.transition = 0
        settings.edgeInset = .infinity
        settings.temporalStrength = -3
        let sanitized = settings.sanitized
        #expect(sanitized.threshold == CustomMaskSettings.balanced.threshold)
        #expect(sanitized.transition > 0)
        #expect(sanitized.edgeInset.isFinite)
        #expect(sanitized.temporalStrength == 0)
        let result = refiner.refine(solid(0.6, in: CGRect(x: 0, y: 0, width: 8, height: 4)), settings: settings)
        #expect(value(result, x: 4, y: 2).isFinite)
    }

    private func solid(_ probability: CGFloat, in bounds: CGRect) -> CIImage {
        let width = Int(bounds.width), height = Int(bounds.height)
        let values = [Float](repeating: Float(probability), count: width * height)
        return CIImage(bitmapData: values.withUnsafeBytes { Data($0) }, bytesPerRow: width * 4,
                       size: bounds.size, format: .Lf, colorSpace: nil)
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
    }

    private func value(_ image: CIImage, x: Int, y: Int) -> Float {
        var result: Float = -1
        context.render(image, toBitmap: &result, rowBytes: MemoryLayout<Float>.size,
                       bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .Lf, colorSpace: nil)
        return result
    }
}
