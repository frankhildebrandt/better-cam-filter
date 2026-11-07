import CoreMediaIO
import Foundation

final class CameraStream: NSObject, CMIOExtensionStreamSource {
    private(set) var stream: CMIOExtensionStream!
    let formats: [CMIOExtensionStreamFormat]
    private(set) var configuration = OutputConfiguration()
    private let direction: CMIOExtensionStream.Direction
    private unowned let camera: CameraDevice

    init(direction: CMIOExtensionStream.Direction, formats: [CMIOExtensionStreamFormat], camera: CameraDevice) {
        self.direction = direction
        self.camera = camera
        self.formats = formats
        super.init()
        stream = CMIOExtensionStream(
            localizedName: direction == .source ? "BetterCam Video" : "BetterCam Input",
            streamID: direction == .source ? CameraConfiguration.sourceID : CameraConfiguration.sinkID,
            direction: direction, clockType: .hostTime, source: self
        )
    }

    private var formatIndex: Int { OutputResolution.allCases.firstIndex(of: configuration.resolution)! }

    var availableProperties: Set<CMIOExtensionProperty> {
        var properties: Set<CMIOExtensionProperty> = [.streamActiveFormatIndex, .streamFrameDuration]
        if direction == .sink {
            properties.formUnion([.streamSinkBufferQueueSize, .streamSinkBuffersRequiredForStartup,
                                  .streamSinkBufferUnderrunCount, .streamSinkEndOfData])
        }
        return properties
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let result = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) { result.activeFormatIndex = formatIndex }
        if properties.contains(.streamFrameDuration) { result.frameDuration = configuration.frameDuration }
        if direction == .sink {
            if properties.contains(.streamSinkBufferQueueSize) { result.sinkBufferQueueSize = 3 }
            if properties.contains(.streamSinkBuffersRequiredForStartup) { result.sinkBuffersRequiredForStartup = 1 }
            if properties.contains(.streamSinkBufferUnderrunCount) { result.sinkBufferUnderrunCount = 0 }
            if properties.contains(.streamSinkEndOfData) { result.sinkEndOfData = 0 }
        }
        return result
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        var updated = configuration
        if let index = streamProperties.activeFormatIndex {
            guard OutputResolution.allCases.indices.contains(index) else { throw VideoError.status(-50) }
            updated.resolution = OutputResolution.allCases[index]
        }
        if let duration = streamProperties.frameDuration {
            guard let rate = OutputConfiguration.frameRates.first(where: {
                CMTimeCompare(duration, CMTime(value: 1, timescale: $0)) == 0
            }) else { throw VideoError.status(-50) }
            updated.frameRate = rate
        }
        try camera.configure(updated, for: direction)
    }

    func apply(_ configuration: OutputConfiguration) {
        guard self.configuration != configuration else { return }
        self.configuration = configuration
        stream.notifyPropertiesChanged([
            .streamActiveFormatIndex: CMIOExtensionPropertyState<AnyObject>(value: formatIndex as NSNumber),
            .streamFrameDuration: CMIOExtensionPropertyState<AnyObject>(value: CMTimeCopyAsDictionary(configuration.frameDuration, allocator: kCFAllocatorDefault)!)
        ])
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        direction == .source || camera.authorizeProducer(client)
    }

    func startStream() throws { camera.start(direction) }
    func stopStream() throws { camera.stop(direction) }
}
