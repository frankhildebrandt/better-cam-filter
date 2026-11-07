import AVFoundation
import CoreImage
import Foundation

struct CaptureUpdate: Sendable {
    let preview: CGImage?
    let outputConnected: Bool
    let error: String?
    let inputResolution: String
    let framesPerSecond: Int
}

/// Session configuration, processing, and CMIO transport share one serial executor.
final class CaptureEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.bettercam.capture", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let processor = FrameProcessor()
    private let output = VirtualCameraOutput()
    private var nextPreview: TimeInterval = 0
    private var nextFrame: TimeInterval = 0
    private var previewOriginal = false
    private var previewMask = false
    private var statisticsStarted: TimeInterval = 0
    private var processedFrames = 0
    private var framesPerSecond = 0
    private let onUpdate: @Sendable (CaptureUpdate) -> Void

    init(onUpdate: @escaping @Sendable (CaptureUpdate) -> Void) {
        self.onUpdate = onUpdate
    }

    func start(deviceID: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    self.stopOnQueue()
                    try self.configure(deviceID: deviceID)
                    self.session.startRunning()
                    guard self.session.isRunning else { throw CaptureError.startFailed }
                    continuation.resume()
                } catch {
                    self.stopOnQueue()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.stopOnQueue()
                continuation.resume()
            }
        }
    }

    func setBackground(_ image: CGImage?) {
        queue.async { self.processor.background = image.map { CIImage(cgImage: $0) } }
    }

    func setSegmentationMode(_ mode: SegmentationMode) {
        queue.async { self.processor.segmentationMode = mode }
    }

    func setSegmentationConfiguration(_ configuration: SegmentationConfiguration) {
        queue.async { self.processor.segmentationConfiguration = configuration }
    }

    func setAccessoriesEnabled(_ enabled: Bool) {
        queue.async { self.processor.accessoriesEnabled = enabled }
    }

    func setKeepMask(_ image: CGImage?) {
        queue.async { self.processor.keepMask = image.map { CIImage(cgImage: $0) } }
    }

    func setPreviewOriginal(_ enabled: Bool) {
        queue.async { self.previewOriginal = enabled }
    }

    func setPreviewMask(_ enabled: Bool) {
        queue.async { self.previewMask = enabled }
    }

    func shutdown() { queue.sync { stopOnQueue() } }

    private func stopOnQueue() {
        session.stopRunning()
        processor.resetSegmentation()
        output.disconnect()
        nextFrame = 0
        nextPreview = 0
        statisticsStarted = ProcessInfo.processInfo.systemUptime
        processedFrames = 0
        framesPerSecond = 0
    }

    private func configure(deviceID: String) throws {
        guard deviceID.caseInsensitiveCompare(CameraConfiguration.deviceID.uuidString) != .orderedSame,
              let device = AVCaptureDevice(uniqueID: deviceID) else { throw CaptureError.missingCamera }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CaptureError.missingCamera }
        session.addInput(input)
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        video.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(video) else { throw CaptureError.startFailed }
        session.addOutput(video)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
            device.activeVideoMinFrameDuration = CameraConfiguration.frameDuration
            device.activeVideoMaxFrameDuration = CameraConfiguration.frameDuration
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard session.isRunning, let input = sampleBuffer.imageBuffer else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= nextFrame else { return }
        nextFrame = now + 1.0 / 31.0
        do {
            let processed = try processor.process(input, at: CMClockGetTime(CMClockGetHostTimeClock()))
            processedFrames += 1
            let elapsed = ProcessInfo.processInfo.systemUptime - statisticsStarted
            if elapsed >= 1 {
                framesPerSecond = Int((Double(processedFrames) / elapsed).rounded())
                statisticsStarted = ProcessInfo.processInfo.systemUptime
                processedFrames = 0
            }
            let connected = try self.output.send(processed)
            guard now >= nextPreview, let buffer = processed.imageBuffer else { return }
            nextPreview = now + 1.0 / 15.0
            let previewImage = previewOriginal
                ? FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: CameraConfiguration.bounds)
                : (previewMask ? processor.previewMask : nil) ?? CIImage(cvPixelBuffer: buffer)
            let image = processor.context.createCGImage(previewImage, from: CameraConfiguration.bounds)
            onUpdate(CaptureUpdate(preview: image, outputConnected: connected, error: nil,
                                   inputResolution: "\(CVPixelBufferGetWidth(input)) × \(CVPixelBufferGetHeight(input))",
                                   framesPerSecond: framesPerSecond))
        } catch {
            guard now >= nextPreview else { return }
            nextPreview = now + 1
            onUpdate(CaptureUpdate(preview: nil, outputConnected: false, error: error.localizedDescription,
                                   inputResolution: "\(CVPixelBufferGetWidth(input)) × \(CVPixelBufferGetHeight(input))",
                                   framesPerSecond: 0))
        }
    }
}

enum CaptureError: LocalizedError {
    case missingCamera, startFailed
    var errorDescription: String? {
        switch self {
        case .missingCamera: "Die ausgewählte Kamera ist nicht verfügbar."
        case .startFailed: "Die Kamera konnte nicht gestartet werden."
        }
    }
}
