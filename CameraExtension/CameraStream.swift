import CoreMediaIO
import Foundation

final class CameraStream: NSObject, CMIOExtensionStreamSource {
    private(set) var stream: CMIOExtensionStream!
    let formats: [CMIOExtensionStreamFormat]
    private let direction: CMIOExtensionStream.Direction
    private unowned let camera: CameraDevice

    init(direction: CMIOExtensionStream.Direction, format: CMIOExtensionStreamFormat, camera: CameraDevice) {
        self.direction = direction
        self.camera = camera
        formats = [format]
        super.init()
        stream = CMIOExtensionStream(
            localizedName: direction == .source ? "BetterCam Video" : "BetterCam Input",
            streamID: direction == .source ? CameraConfiguration.sourceID : CameraConfiguration.sinkID,
            direction: direction, clockType: .hostTime, source: self
        )
    }

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
        if properties.contains(.streamActiveFormatIndex) { result.activeFormatIndex = 0 }
        if properties.contains(.streamFrameDuration) { result.frameDuration = CameraConfiguration.frameDuration }
        if direction == .sink {
            if properties.contains(.streamSinkBufferQueueSize) { result.sinkBufferQueueSize = 3 }
            if properties.contains(.streamSinkBuffersRequiredForStartup) { result.sinkBuffersRequiredForStartup = 1 }
            if properties.contains(.streamSinkBufferUnderrunCount) { result.sinkBufferUnderrunCount = 0 }
            if properties.contains(.streamSinkEndOfData) { result.sinkEndOfData = 0 }
        }
        return result
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let index = streamProperties.activeFormatIndex, index != 0 { throw VideoError.status(-50) }
        if let duration = streamProperties.frameDuration, duration != CameraConfiguration.frameDuration {
            throw VideoError.status(-50)
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        direction == .source || camera.authorizeProducer(client)
    }

    func startStream() throws { camera.start(direction) }
    func stopStream() throws { camera.stop(direction) }
}
