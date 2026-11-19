import CoreImage
import CoreMediaIO
import Foundation
import IOKit.audio
import OSLog

/// Provider callbacks and timer state are confined to `queue`.
final class CameraDevice: NSObject, CMIOExtensionDeviceSource, @unchecked Sendable {
    let queue = DispatchQueue(label: "de.bettercam.extension", qos: .userInitiated)
    private(set) var device: CMIOExtensionDevice!
    private var source: CameraStream!
    private var sink: CameraStream!
    private var producer: CMIOExtensionClient?
    private var sinkRunning = false
    private var sourceClients = 0
    private let demandProperty = CMIOExtensionProperty(rawValue: CameraConfiguration.sourceDemandProperty)
    private var timer: DispatchSourceTimer?
    private var consuming = false
    private var generation = 0
    private var latestBuffer: CVPixelBuffer?
    private var lastReceived: Double = 0
    private var black: CVPixelBuffer
    private var outputPool: CVPixelBufferPool
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let logger = Logger(subsystem: "de.bettercam.camera", category: "Transport")
    private let producerAuthorization = ProducerAuthorization()

    init(localizedName: String) throws {
        outputPool = try VideoBuffers.makePool()
        black = try VideoBuffers.makePixelBuffer(from: outputPool)
        CIContext().render(CIImage(color: .black).cropped(to: CameraConfiguration.bounds), to: black)
        super.init()
        device = CMIOExtensionDevice(localizedName: localizedName,
                                     deviceID: CameraConfiguration.deviceID, legacyDeviceID: nil, source: self)
        let formats = try OutputResolution.allCases.map { resolution in
            var description: CMVideoFormatDescription?
            try VideoBuffers.check(CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                codecType: kCVPixelFormatType_32BGRA, width: Int32(resolution.width), height: Int32(resolution.height),
                extensions: nil, formatDescriptionOut: &description))
            guard let description else { throw VideoError.allocation }
            return CMIOExtensionStreamFormat(formatDescription: description,
                maxFrameDuration: CMTime(value: 1, timescale: 15),
                minFrameDuration: CMTime(value: 1, timescale: 60),
                validFrameDurations: OutputConfiguration.frameRates.map {
                    CMTime(value: 1, timescale: $0)
                })
        }
        source = CameraStream(direction: .source, formats: formats, camera: self)
        sink = CameraStream(direction: .sink, formats: formats, camera: self)
        try device.addStream(source.stream)
        try device.addStream(sink.stream)
    }

    var availableProperties: Set<CMIOExtensionProperty> { [.deviceTransportType, .deviceModel, demandProperty] }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let result = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) { result.transportType = kIOAudioDeviceTransportTypeVirtual }
        if properties.contains(.deviceModel) { result.model = "BetterCam Virtual Camera" }
        if properties.contains(demandProperty) { result.setPropertyState(demandState, forProperty: demandProperty) }
        return result
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}

    private var demandState: CMIOExtensionPropertyState<AnyObject> {
        CMIOExtensionPropertyState(value: (sourceClients > 0 ? "1" : "0") as NSString,
                                   attributes: .readOnlyPropertyAttribute)
    }

    func configure(_ configuration: OutputConfiguration, for direction: CMIOExtensionStream.Direction) throws {
        // The producer can connect after a video app has negotiated its source format.
        if direction == .sink, sourceClients > 0 {
            sink.apply(configuration)
            return
        }
        if configuration.resolution != source.configuration.resolution {
            let pool = try VideoBuffers.makePool(configuration: configuration)
            let buffer = try VideoBuffers.makePixelBuffer(from: pool)
            context.render(CIImage(color: .black).cropped(to: configuration.bounds), to: buffer)
            outputPool = pool
            black = buffer
        }
        // A producer establishes the preferred output; clients may negotiate their own source format.
        if direction == .sink { sink.apply(configuration) }
        source.apply(configuration)
        timer?.schedule(deadline: .now(), repeating: 1.0 / Double(configuration.frameRate), leeway: .milliseconds(1))
    }

    func authorizeProducer(_ client: CMIOExtensionClient) -> Bool {
        logger.notice("Producer authorization: pid=\(client.pid) signingID=\(client.signingID ?? "nil", privacy: .public) ownerPID=\(self.producer?.pid ?? -1) sameClient=\(self.producer?.clientID == client.clientID)")
        let status = producerAuthorization.validationStatus(processID: client.pid)
        guard status == noErr else {
            logger.error("Producer rejected: code validation status=\(status) expectedTeam=\(self.producerAuthorization.teamIdentifier ?? "nil", privacy: .public)")
            return false
        }
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
        let hadDemand = sourceClients > 0
        logger.notice("Start stream direction=\(direction.rawValue)")
        if direction == .source { sourceClients += 1 } else { sinkRunning = true }
        if !hadDemand && sourceClients > 0 { device.notifyPropertiesChanged([demandProperty: demandState]) }
        updateTimer()
    }

    func stop(_ direction: CMIOExtensionStream.Direction) {
        let hadDemand = sourceClients > 0
        logger.notice("Stop stream direction=\(direction.rawValue)")
        if direction == .source { sourceClients = max(0, sourceClients - 1) } else { clearProducer() }
        if hadDemand && sourceClients == 0 { device.notifyPropertiesChanged([demandProperty: demandState]) }
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
        timer.schedule(deadline: .now(), repeating: 1.0 / Double(source.configuration.frameRate), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    private func tick() {
        consumeNext()
        guard sourceClients > 0 else { return }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        // Never freeze the last camera frame after a stop, crash, or stalled producer.
        var buffer = sinkRunning && now.seconds - lastReceived < 0.5 ? (latestBuffer ?? black) : black
        let configuration = source.configuration
        if CVPixelBufferGetWidth(buffer) != configuration.width || CVPixelBufferGetHeight(buffer) != configuration.height {
            guard let resized = try? VideoBuffers.makePixelBuffer(from: outputPool) else { return }
            context.render(FrameComposition.aspectFill(CIImage(cvPixelBuffer: buffer), in: configuration.bounds), to: resized)
            buffer = resized
        }
        guard let sample = try? VideoBuffers.makeSampleBuffer(buffer, at: now, duration: configuration.frameDuration) else { return }
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
           CVPixelBufferGetWidth(buffer) == sink.configuration.width,
           CVPixelBufferGetHeight(buffer) == sink.configuration.height,
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
