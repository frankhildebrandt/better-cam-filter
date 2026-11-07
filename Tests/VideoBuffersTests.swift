import CoreMedia
import CoreVideo
import Testing
@testable import BetterCamCore

struct VideoBuffersTests {
    @Test(arguments: OutputResolution.allCases) func selectedResolutionReachesPixelAndSampleBuffers(_ resolution: OutputResolution) throws {
        let configuration = OutputConfiguration(resolution: resolution, frameRate: 25)
        let pool = try VideoBuffers.makePool(configuration: configuration)
        let buffer = try VideoBuffers.makePixelBuffer(from: pool)
        let time = CMTime(value: 321, timescale: 100)
        let sample = try VideoBuffers.makeSampleBuffer(buffer, at: time, duration: configuration.frameDuration)
        let format = try #require(sample.formatDescription)
        #expect(CVPixelBufferGetWidth(buffer) == resolution.width)
        #expect(CVPixelBufferGetHeight(buffer) == resolution.height)
        #expect(CMVideoFormatDescriptionGetDimensions(format).width == resolution.width)
        #expect(CMVideoFormatDescriptionGetDimensions(format).height == resolution.height)
        #expect(sample.duration == CMTime(value: 1, timescale: 25))
        #expect(sample.presentationTimeStamp == time)
    }

    @Test func outputConfigurationPersistsAndRejectsInvalidCadence() throws {
        let original = OutputConfiguration(resolution: .uhd2160, frameRate: 60)
        let decoded = try JSONDecoder().decode(OutputConfiguration.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(OutputConfiguration(frameRate: 0).sanitized.frameRate == 30)
        #expect(OutputConfiguration(frameRate: -1).frameDuration == CMTime(value: 1, timescale: 30))
    }

    @Test(arguments: OutputConfiguration.frameRates) func selectedFrameRateReachesSampleTiming(_ frameRate: Int32) throws {
        let configuration = OutputConfiguration(resolution: .hd720, frameRate: frameRate)
        let buffer = try VideoBuffers.makePixelBuffer(from: VideoBuffers.makePool(configuration: configuration))
        let sample = try VideoBuffers.makeSampleBuffer(buffer, at: .zero, duration: configuration.frameDuration)
        #expect(sample.duration == CMTime(value: 1, timescale: frameRate))
    }

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
