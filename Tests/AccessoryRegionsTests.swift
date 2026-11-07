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

    private func canvas() -> [UInt8] { [UInt8](repeating: 255, count: width * height * 4) }

    private func paint(_ pixels: inout [UInt8], x: Range<Int>, y: Range<Int>, color: [UInt8]) {
        for row in y { for column in x {
            let offset = (row * width + column) * 4
            for channel in 0..<3 { pixels[offset + channel] = color[channel] }
        } }
    }
}
