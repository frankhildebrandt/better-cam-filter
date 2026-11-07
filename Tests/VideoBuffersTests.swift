import CoreMedia
import CoreVideo
import Testing
@testable import BetterCamCore

struct VideoBuffersTests {
    @Test func outputHasNegotiatedFormatAndHostTimestamp() throws {
        let pool = try VideoBuffers.makePool()
        let buffer = try VideoBuffers.makePixelBuffer(from: pool)
        let time = CMTime(value: 123_456, timescale: 1000)
        let sample = try VideoBuffers.makeSampleBuffer(buffer, at: time)
        let format = try #require(sample.formatDescription)
        #expect(CMVideoFormatDescriptionGetDimensions(format).width == 1920)
        #expect(CMVideoFormatDescriptionGetDimensions(format).height == 1080)
        #expect(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA)
        #expect(CVPixelBufferGetIOSurface(buffer) != nil)
        #expect(sample.presentationTimeStamp == time)
        #expect(sample.duration == CMTime(value: 1, timescale: 30))
    }

    @Test func poolBoundsOutstandingFrames() throws {
        let pool = try VideoBuffers.makePool()
        var held = [CVPixelBuffer]()
        for _ in 0..<8 { held.append(try VideoBuffers.makePixelBuffer(from: pool)) }
        #expect(throws: (any Error).self) { try VideoBuffers.makePixelBuffer(from: pool) }
        #expect(held.count == 8)
    }
}
