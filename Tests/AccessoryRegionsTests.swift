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

    @Test func fineMetalJoinedToAGrayWallUsesOnlyMatchingCoarseConnectorPixels() {
        func frame(scale: Int) -> AccessorySamples {
            let w = 512 * scale, h = 288 * scale
            var rgba = [UInt8](repeating: 255, count: w * h * 4)
            var alpha = [UInt8](repeating: 0, count: w * h)
            func paint(_ x: Range<Int>, _ y: Range<Int>, gray: UInt8, person: Bool = false) {
                for row in (y.lowerBound * scale)..<(y.upperBound * scale) {
                    for column in (x.lowerBound * scale)..<(x.upperBound * scale) {
                        let index = row * w + column
                        for channel in 0..<3 { rgba[index * 4 + channel] = gray }
                        if person { alpha[index] = 255 }
                    }
                }
            }
            paint(365..<440, 90..<270, gray: 35, person: true)
            paint(220..<365, 206..<215, gray: 35) // Arm.
            paint(150..<205, 208..<213, gray: 30) // Cable.
            paint(205..<220, 206..<215, gray: 155) // Sleeve.
            paint(207..<218, 207..<214, gray: 225) // Reflection.
            paint(185..<245, 130..<190, gray: 155) // Wall.
            if scale == 2 {
                // A one-pixel seam joins the gray regions only at the finer resolution.
                for row in (190 * scale)..<(206 * scale) {
                    let offset = (row * w + 210 * scale) * 4
                    for channel in 0..<3 { rgba[offset + channel] = 155 }
                }
                let edge = (214 * scale * w + 210 * scale) * 4
                for channel in 0..<3 { rgba[edge + channel] = 245 }
            }
            return AccessorySamples(rgba: rgba, alpha: alpha, width: w, height: h)
        }
        let coarse = frame(scale: 1), fine = frame(scale: 2)
        var evidence = fine.proposal().evidence
        func index(_ x: Int, _ y: Int) -> Int { 2 * y * fine.width + 2 * x }
        #expect(evidence[index(211, 210)] == 0)
        #expect(evidence[index(206, 210)] == 0)
        AccessoryRegions.restoreMetal(from: coarse, in: fine, evidence: &evidence)
        #expect(evidence[index(211, 210)] == 255) // Reflection.
        #expect(evidence[index(206, 210)] == 255) // Gray metal.
        #expect(evidence[index(210, 214)] == 0)   // Bright edge outside the metal color.
        #expect(evidence[index(210, 200)] == 0)   // Seam.
        #expect(evidence[index(210, 170)] == 0)   // Wall.
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
