import CoreImage
import Testing
@testable import BetterCamCore

struct ReactionRendererTests {
    private let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
    private let anchor = CGPoint(x: 0.5, y: 0.4)

    @Test(arguments: ReactionKind.allCases)
    func everyReactionRendersVisibleTransparentArtwork(_ reaction: ReactionKind) {
        let layers = ReactionRenderer().frame(reaction: reaction, progress: 0.5, anchor: anchor, bounds: bounds)
        let image = flatten(layers)
        #expect(bounds.contains(image.extent))
        #expect(!image.extent.isEmpty)
        #expect(!image.extent.isInfinite)
        let alpha = pixels(image).enumerated().filter { $0.offset % 4 == 3 }.map(\.element)
        #expect(alpha.contains { $0 > 100 })
        #expect(alpha.contains(0))
        #expect(alpha.filter { $0 > 0 }.count < Int(bounds.width * bounds.height * 0.5))
    }

    @Test(arguments: ReactionKind.allCases)
    func reactionsStartAndEndWithoutLeavingAnyPixels(_ reaction: ReactionKind) {
        let renderer = ReactionRenderer()
        for progress in [-1.0, 0, 1, 2, .nan, .infinity] {
            let layers = renderer.frame(reaction: reaction, progress: progress, anchor: anchor, bounds: bounds)
            #expect(layers.foreground == nil)
            #expect(layers.background == nil)
        }
    }

    @Test(arguments: ReactionKind.allCases)
    func translatedOutputBoundsPreserveTheEntireAnimation(_ reaction: ReactionKind) {
        let renderer = ReactionRenderer()
        let original = renderer.frame(reaction: reaction, progress: 0.42, anchor: anchor, bounds: bounds)
        let shiftedBounds = bounds.offsetBy(dx: 43, dy: -17)
        let shifted = renderer.frame(reaction: reaction, progress: 0.42, anchor: anchor, bounds: shiftedBounds)
        let aligned = flatten(shifted).transformed(by: CGAffineTransform(translationX: -43, y: 17))
        let originalPixels = pixels(flatten(original))
        let alignedPixels = pixels(aligned)
        let maximumDifference = zip(originalPixels, alignedPixels).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(maximumDifference <= 2)
    }

    @Test func rainbowSeparatesOccludedArtworkFromForegroundConfetti() {
        let renderer = ReactionRenderer()
        let layers = renderer.frame(reaction: .rainbowYay, progress: 0.5, anchor: anchor, bounds: bounds)
        #expect(layers.background != nil)
        #expect(layers.foreground != nil)
        for reaction in ReactionKind.allCases where reaction != .rainbowYay {
            #expect(renderer.frame(reaction: reaction, progress: 0.5, anchor: anchor, bounds: bounds).background == nil)
        }
    }

    @Test func handAttachedReactionsFollowTheAnchor() {
        let renderer = ReactionRenderer()
        for reaction in [ReactionKind.goodBean, .pawFive, .lovePuff, .tinyLove] {
            let left = renderer.frame(reaction: reaction, progress: 0.42,
                                      anchor: CGPoint(x: 0.25, y: 0.4), bounds: bounds)
            let right = renderer.frame(reaction: reaction, progress: 0.42,
                                       anchor: CGPoint(x: 0.75, y: 0.4), bounds: bounds)
            #expect(alphaCenter(flatten(right)) - alphaCenter(flatten(left)) > 80)
        }
    }

    @Test func invalidGeometryProducesNoLayers() {
        let renderer = ReactionRenderer()
        let invalidAnchors = [CGPoint(x: Double.nan, y: 0.5), CGPoint(x: 0.5, y: Double.infinity)]
        for point in invalidAnchors {
            let result = renderer.frame(reaction: .goodBean, progress: 0.5, anchor: point, bounds: bounds)
            #expect(result.foreground == nil)
        }
        for rect in [CGRect.zero, CGRect.infinite, CGRect(x: 0, y: 0, width: Double.nan, height: 180)] {
            let result = renderer.frame(reaction: .goodBean, progress: 0.5, anchor: anchor, bounds: rect)
            #expect(result.foreground == nil)
        }
    }

    private func flatten(_ layers: ReactionLayers) -> CIImage {
        (layers.foreground ?? .empty()).composited(over: layers.background ?? .empty())
    }

    private func pixels(_ image: CIImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: Int(bounds.width * bounds.height) * 4)
        CIContext().render(image, toBitmap: &data, rowBytes: Int(bounds.width) * 4,
                           bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return data
    }

    private func alphaCenter(_ image: CIImage) -> Double {
        let data = pixels(image)
        var total = 0.0
        var weightedX = 0.0
        for index in stride(from: 3, to: data.count, by: 4) {
            let weight = Double(data[index])
            total += weight
            weightedX += Double((index / 4) % Int(bounds.width)) * weight
        }
        return total > 0 ? weightedX / total : 0
    }
}
