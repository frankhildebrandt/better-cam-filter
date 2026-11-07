import Testing
@testable import BetterCamCore

struct AccessoryRegionsTests {
    private let width = 100
    private let height = 60

    @Test func growsFromPersonIntoChairArmAndThinColoredCable() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<62, y: 24..<60, color: [25, 24, 28])
        for y in 24..<60 { for x in 40..<62 { alpha[y * width + x] = 255 } }
        paint(&rgba, x: 63..<76, y: 16..<51, color: [30, 30, 32])
        paint(&rgba, x: 15..<38, y: 50..<56, color: [40, 40, 43])
        paint(&rgba, x: 0..<18, y: 49..<50, color: [240, 45, 80])
        paint(&rgba, x: 0..<20, y: 0..<45, color: [130, 65, 35])
        let result = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(result[20 * width + 70] == 255) // Chair.
        #expect(result[53 * width + 25] == 255) // Arm.
        #expect(result[49 * width + 5] == 255) // Cable.
        #expect(result[50 * width + 39] == 255) // Short bright connector gap.
        #expect(result[30 * width + 10] == 0) // Brown door.
        #expect(result[10 * width + 85] == 0) // Bright background.
        #expect(zip(alpha, result).allSatisfy { $0 <= $1 })
    }

    @Test func doesNotGrowWithoutConfidentSemanticSeeds() {
        var rgba = canvas()
        paint(&rgba, x: 20..<70, y: 20..<50, color: [20, 20, 20])
        let alpha = [UInt8](repeating: 0, count: width * height)
        #expect(AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height) == alpha)
    }

    @Test func rejectsDarkWallConnectedToPersonAtUpperFrameEdge() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<60, y: 0..<60, color: [25, 25, 25])
        for y in 25..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        let result = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(result[5 * width + 50] == 0)
        #expect(result[40 * width + 50] == 255)
    }

    @Test func leavesDisconnectedDarkBackgroundUnchanged() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<60, y: 25..<60, color: [25, 25, 25])
        paint(&rgba, x: 5..<15, y: 5..<15, color: [25, 25, 25])
        for y in 25..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        let result = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(result[10 * width + 10] == 0)
    }

    @Test func rejectsLargeDarkAdditionsEvenBelowUpperBorder() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 0..<95, y: 10..<60, color: [25, 25, 25])
        for y in 25..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        #expect(AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height) == alpha)
    }

    @Test func invalidDimensionsLeaveTheMaskUntouched() {
        let alpha: [UInt8] = [127]
        #expect(AccessoryRegions.refine(rgba: [], alpha: alpha, width: -1, height: -1) == alpha)
        #expect(AccessoryRegions.refine(rgba: [], alpha: alpha, width: 0, height: 1) == alpha)
    }

    @Test func headAdjacentBoardMarkCannotUseHeadAsAnAccessoryAnchor() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<60, y: 10..<60, color: [25, 25, 25])
        paint(&rgba, x: 37..<39, y: 12..<20, color: [25, 25, 25])
        for y in 10..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        let result = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(result[15 * width + 37] == 0)
    }

    @Test func rejectedLargeBackgroundDoesNotRemoveValidChair() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<60, y: 25..<60, color: [25, 25, 25])
        paint(&rgba, x: 62..<76, y: 16..<51, color: [25, 25, 25])
        for y in 25..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        let first = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        paint(&rgba, x: 0..<38, y: 0..<60, color: [25, 25, 25])
        let second = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(first[20 * width + 70] == 255)
        #expect(second[20 * width + 70] == 255)
        #expect(second[30 * width + 10] == 0)
    }

    @Test func smallDarkBoardMarksNearTorsoAreNotAccessories() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<60, y: 25..<60, color: [25, 25, 25])
        paint(&rgba, x: 37..<39, y: 50..<52, color: [25, 25, 25])
        for y in 25..<60 { for x in 40..<60 { alpha[y * width + x] = 255 } }
        let result = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(result[50 * width + 37] == 0)
    }

    @Test func anotherRegionCrossingAreaLimitDoesNotToggleTheChair() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 45..<55, y: 25..<60, color: [25, 25, 25])
        paint(&rgba, x: 57..<80, y: 20..<60, color: [25, 25, 25])
        paint(&rgba, x: 15..<43, y: 40..<60, color: [25, 25, 25])
        for y in 25..<60 { for x in 45..<55 { alpha[y * width + x] = 255 } }
        let first = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        paint(&rgba, x: 13..<43, y: 40..<60, color: [25, 25, 25])
        let second = AccessoryRegions.refine(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(first[30 * width + 70] == 255)
        #expect(second[30 * width + 70] == 255)
    }

    @Test func accessoryEvidenceExistsWhilePersonAlreadyCoversTheMic() {
        var rgba = canvas()
        var alpha = [UInt8](repeating: 0, count: width * height)
        paint(&rgba, x: 40..<62, y: 24..<60, color: [25, 24, 28])
        paint(&rgba, x: 30..<39, y: 45..<60, color: [40, 40, 43])
        for y in 24..<60 { for x in 40..<62 { alpha[y * width + x] = 255 } }
        for y in 45..<60 { for x in 30..<39 { alpha[y * width + x] = 255 } }
        let proposal = AccessoryRegions.propose(rgba: rgba, alpha: alpha, width: width, height: height)
        #expect(proposal.alpha[50 * width + 35] == alpha[50 * width + 35])
        #expect(proposal.evidence[50 * width + 35] == 255)
        #expect(proposal.evidence[30 * width + 50] == 0) // Upper semantic area does not seed object history.
    }

    private func canvas() -> [UInt8] { [UInt8](repeating: 255, count: width * height * 4) }

    private func paint(_ pixels: inout [UInt8], x: Range<Int>, y: Range<Int>, color: [UInt8]) {
        for row in y { for column in x {
            let offset = (row * width + column) * 4
            for channel in 0..<3 { pixels[offset + channel] = color[channel] }
        } }
    }
}
