import CoreImage
import CoreMediaIO
import Foundation
import IOKit.audio

/// Provider callbacks and timer state are confined to `queue`.
final class CameraDevice: NSObject, CMIOExtensionDeviceSource, @unchecked Sendable {
    let queue = DispatchQueue(label: "de.bettercam.extension", qos: .userInitiated)
    private(set) var device: CMIOExtensionDevice!
    private var source: CameraStream!
    private var sink: CameraStream!
    private var producer: CMIOExtensionClient?
    private var sinkRunning = false
    private var sourceClients = 0
    private var timer: DispatchSourceTimer?
    private var consuming = false
    private var generation = 0
    private var latestBuffer: CVPixelBuffer?
    private var lastReceived: Double = 0
    private let black: CVPixelBuffer

    init(localizedName: String) throws {
        let pool = try VideoBuffers.makePool()
        black = try VideoBuffers.makePixelBuffer(from: pool)
        CIContext().render(CIImage(color: .black).cropped(to: CameraConfiguration.bounds), to: black)
        super.init()
        device = CMIOExtensionDevice(localizedName: localizedName,
                                     deviceID: CameraConfiguration.deviceID, legacyDeviceID: nil, source: self)
        let sample = try VideoBuffers.makeSampleBuffer(black, at: .zero)
        guard let description = sample.formatDescription else { throw VideoError.allocation }
        let format = CMIOExtensionStreamFormat(formatDescription: description,
                                               maxFrameDuration: CameraConfiguration.frameDuration,
                                               minFrameDuration: CameraConfiguration.frameDuration,
                                               validFrameDurations: nil)
        source = CameraStream(direction: .source, format: format, camera: self)
        sink = CameraStream(direction: .sink, format: format, camera: self)
        try device.addStream(source.stream)
        try device.addStream(sink.stream)
    }

    var availableProperties: Set<CMIOExtensionProperty> { [.deviceTransportType, .deviceModel] }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let result = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) { result.transportType = kIOAudioDeviceTransportTypeVirtual }
        if properties.contains(.deviceModel) { result.model = "BetterCam Virtual Camera" }
        return result
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}

    func authorizeProducer(_ client: CMIOExtensionClient) -> Bool {
        guard client.signingID == "de.bettercam.app" else { return false }
        guard producer == nil || producer?.clientID == client.clientID else { return false }
        producer = client
        return true
    }

    func disconnect(_ client: CMIOExtensionClient) {
        guard producer?.clientID == client.clientID else { return }
        clearProducer()
        updateTimer()
    }

    func start(_ direction: CMIOExtensionStream.Direction) {
        if direction == .source { sourceClients += 1 } else { sinkRunning = true }
        updateTimer()
    }

    func stop(_ direction: CMIOExtensionStream.Direction) {
        if direction == .source { sourceClients = max(0, sourceClients - 1) } else { clearProducer() }
        updateTimer()
    }

    private func clearProducer() {
        sinkRunning = false
        producer = nil
        latestBuffer = nil
        lastReceived = 0
        generation += 1
        consuming = false
    }

    private func updateTimer() {
        guard sourceClients > 0 || sinkRunning else {
            timer?.cancel()
            timer = nil
            latestBuffer = nil
            return
        }
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / Double(CameraConfiguration.frameRate), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    private func tick() {
        consumeNext()
        guard sourceClients > 0 else { return }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        // Never freeze the last camera frame after a stop, crash, or stalled producer.
        let buffer = sinkRunning && now.seconds - lastReceived < 0.5 ? (latestBuffer ?? black) : black
        guard let sample = try? VideoBuffers.makeSampleBuffer(buffer, at: now) else { return }
        source.stream.send(sample, discontinuity: [], hostTimeInNanoseconds: UInt64(now.seconds * 1_000_000_000))
    }

    private func consumeNext() {
        guard sinkRunning, !consuming, let producer else { return }
        consuming = true
        let requestGeneration = generation
        sink.stream.consumeSampleBuffer(from: producer) { [weak self] sample, sequence, _, _, error in
            guard let self else { return }
            // CoreMediaIO completes consumption asynchronously; rejoin the provider queue.
            let delivery = SinkDelivery(sample: sample, sequence: sequence, failed: error != nil)
            self.queue.async { self.receive(delivery, generation: requestGeneration) }
        }
    }

    private func receive(_ delivery: SinkDelivery, generation requestGeneration: Int) {
        guard requestGeneration == generation else { return }
        consuming = false
        guard sinkRunning, !delivery.failed, let sample = delivery.sample else { return }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        if let buffer = sample.imageBuffer,
           CVPixelBufferGetWidth(buffer) == CameraConfiguration.width,
           CVPixelBufferGetHeight(buffer) == CameraConfiguration.height,
           CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
            latestBuffer = buffer
            lastReceived = now.seconds
        }
        sink.stream.notifyScheduledOutputChanged(CMIOExtensionScheduledOutput(
            sequenceNumber: delivery.sequence, hostTimeInNanoseconds: UInt64(now.seconds * 1_000_000_000)
        ))
    }
}

/// Retains a sample while transferring ownership to the provider's serial queue.
private struct SinkDelivery: @unchecked Sendable {
    let sample: CMSampleBuffer?
    let sequence: UInt64
    let failed: Bool
}
