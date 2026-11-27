import AVFoundation
import CoreImage
import Foundation

enum PreviewSource: Sendable { case mainWindow, gestures }

struct CaptureUpdate: Sendable {
    let preview: CGImage?
    let outputPreview: CGImage?
    let outputConnected: Bool
    let error: String?
    let inputResolution: String
    let framesPerSecond: Int
    let detectedGesture: GestureKind?
    let gestureError: String?
}

/// Two serial stages overlap: camera frames arrive on `analysisQueue`, which runs Vision or Core ML,
/// while session configuration, mask refinement, composition and CMIO transport share `queue`.
/// Each mask therefore still belongs to exactly its own frame.
final class CaptureEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.bettercam.capture", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "de.bettercam.analysis", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let analysis = FrameAnalysisStage()
    private let handoff = FrameHandoff()
    private let processor = FrameProcessor()
    private var analysisNeedsReactionMask = false
    private let output = VirtualCameraOutput()
    private var nextPreview: TimeInterval = 0
    private var visiblePreviews = Set<PreviewSource>()
    private var previewOriginal = false
    private var previewMask = false
    private var statisticsStarted: TimeInterval = 0
    private var processedFrames = 0
    private var framesPerSecond = 0
    private var outputError: String?
    private var outputConfiguration = OutputConfiguration()
    private let onUpdate: @Sendable (CaptureUpdate) -> Void
    /// Previews only monitor the stream; reading back full 1080p or 4K frames would cost several ms each.
    private static let previewMaxWidth: CGFloat = 1280

    var captureSession: AVCaptureSession { session }

    init(onUpdate: @escaping @Sendable (CaptureUpdate) -> Void) {
        self.onUpdate = onUpdate
    }

    func start(deviceID: String, configuration: OutputConfiguration) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    self.stopOnQueue()
                    self.outputConfiguration = configuration.sanitized
                    self.processor.outputConfiguration = self.outputConfiguration
                    self.output.configuration = self.outputConfiguration
                    let analysisConfiguration = self.outputConfiguration
                    self.analysisQueue.async { self.analysis.outputConfiguration = analysisConfiguration }
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
        analysisQueue.async { self.analysis.backgroundEnabled = image != nil }
    }

    func setSegmentationConfiguration(_ configuration: SegmentationConfiguration) {
        queue.async { self.processor.segmentationConfiguration = configuration }
        analysisQueue.async { self.analysis.segmentationConfiguration = configuration }
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

    func setPreviewVisible(_ visible: Bool, for source: PreviewSource) {
        queue.async {
            guard self.visiblePreviews.contains(source) != visible else { return }
            if visible { self.visiblePreviews.insert(source) } else { self.visiblePreviews.remove(source) }
            self.nextPreview = 0
        }
    }

    func setGestureConfiguration(_ configuration: GestureConfiguration) {
        queue.async { self.processor.gestureConfiguration = configuration }
    }

    func previewReaction(_ reaction: ReactionKind, for gesture: GestureKind) {
        queue.async {
            guard self.session.isRunning else { return }
            self.processor.previewReaction(reaction, for: gesture, at: CMClockGetTime(CMClockGetHostTimeClock()).seconds)
        }
    }

    func shutdown() { queue.sync { stopOnQueue() } }

    private func stopOnQueue() {
        session.stopRunning()
        // Frames already analyzed for the old session must not reach the next one.
        handoff.invalidate()
        analysisQueue.async { self.analysis.reset() }
        processor.resetSegmentation()
        processor.resetGestures()
        reportReactionMaskNeed()
        output.disconnect()
        nextPreview = 0
        statisticsStarted = ProcessInfo.processInfo.systemUptime
        processedFrames = 0
        framesPerSecond = 0
        outputError = nil
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
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        video.setSampleBufferDelegate(self, queue: analysisQueue)
        guard session.canAddOutput(video) else { throw CaptureError.startFailed }
        session.addOutput(video)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        // Prefer the requested size and cadence; lower-resolution cameras may still be upscaled.
        let requestedRate = Double(outputConfiguration.frameRate)
        let candidates = device.formats.filter {
            $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= requestedRate && $0.maxFrameRate >= requestedRate }
        }
        let formats = candidates.isEmpty ? device.formats : candidates
        let targetWidth = outputConfiguration.width
        if let format = formats.min(by: { left, right in
            func cost(_ format: AVCaptureDevice.Format) -> Int {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let undersized = dimensions.width < targetWidth ? targetWidth : 0
                return abs(Int(dimensions.width) - targetWidth) + abs(Int(dimensions.height) - outputConfiguration.height) + undersized
            }
            return cost(left) < cost(right)
        }) {
            device.activeFormat = format
        }
        if let range = device.activeFormat.videoSupportedFrameRateRanges.min(by: {
            abs(min($0.maxFrameRate, max($0.minFrameRate, requestedRate)) - requestedRate)
                < abs(min($1.maxFrameRate, max($1.minFrameRate, requestedRate)) - requestedRate)
        }) {
            let rate = min(range.maxFrameRate, max(range.minFrameRate, requestedRate))
            let duration = rate == range.maxFrameRate ? range.minFrameDuration
                : (rate == range.minFrameRate ? range.maxFrameDuration : outputConfiguration.frameDuration)
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        }
    }

    /// Runs on `analysisQueue`. A frame is dropped when another analyzed frame still waits for composition.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard session.isRunning, let input = sampleBuffer.imageBuffer,
              analysis.admit(at: ProcessInfo.processInfo.systemUptime),
              let token = handoff.reserve() else { return }
        let frame = analysis.analyze(input, at: CMClockGetTime(CMClockGetHostTimeClock()))
        queue.async {
            guard self.handoff.begin(token), self.session.isRunning else { return }
            self.compose(frame)
        }
    }

    /// Tell the analysis stage when rear reactions start or stop needing a person mask.
    private func reportReactionMaskNeed() {
        let needed = processor.reactionsNeedMask
        guard needed != analysisNeedsReactionMask else { return }
        analysisNeedsReactionMask = needed
        analysisQueue.async { self.analysis.reactionsNeedMask = needed }
    }

    /// Runs on `queue`: refine, compose, send to the virtual camera and publish previews.
    private func compose(_ frame: AnalyzedFrame) {
        let input = frame.input
        let now = ProcessInfo.processInfo.systemUptime
        defer { reportReactionMaskNeed() }
        do {
            let needsMask = visiblePreviews.contains(.mainWindow) && previewMask && !previewOriginal && now >= nextPreview
            let processed = try processor.process(frame, keepPreviewMask: needsMask)
            processedFrames += 1
            let elapsed = ProcessInfo.processInfo.systemUptime - statisticsStarted
            if elapsed >= 1 {
                framesPerSecond = Int((Double(processedFrames) / elapsed).rounded())
                statisticsStarted = ProcessInfo.processInfo.systemUptime
                processedFrames = 0
            }
            // Transport failures must not interrupt the independent local preview.
            let connected: Bool
            do {
                connected = try self.output.send(processed)
                if connected { outputError = nil }
            } catch {
                connected = false
                outputError = error.localizedDescription
            }
            guard now >= nextPreview, let buffer = processed.imageBuffer else { return }
            nextPreview = now + (visiblePreviews.isEmpty ? 1 : 1.0 / 15.0)
            let alternate = previewOriginal && visiblePreviews.contains(.mainWindow)
                ? frame.foreground
                : processor.previewMask
            let previews = Self.renderPreviews(for: visiblePreviews, alternate: alternate, output: CIImage(cvPixelBuffer: buffer)) {
                let preview = FrameComposition.preview($0.cropped(to: outputConfiguration.bounds), maxWidth: Self.previewMaxWidth)
                return processor.context.createCGImage(preview, from: preview.extent)
            }
            onUpdate(CaptureUpdate(preview: previews.main, outputPreview: previews.gestures, outputConnected: connected, error: outputError,
                                   inputResolution: "\(CVPixelBufferGetWidth(input)) × \(CVPixelBufferGetHeight(input))",
                                   framesPerSecond: framesPerSecond, detectedGesture: processor.detectedGesture,
                                   gestureError: processor.gestureError))
        } catch {
            guard now >= nextPreview else { return }
            nextPreview = now + 1
            onUpdate(CaptureUpdate(preview: nil, outputPreview: nil, outputConnected: false, error: error.localizedDescription,
                                   inputResolution: "\(CVPixelBufferGetWidth(input)) × \(CVPixelBufferGetHeight(input))",
                                   framesPerSecond: 0, detectedGesture: nil, gestureError: processor.gestureError))
        }
    }

    static func renderPreviews(for visible: Set<PreviewSource>, alternate: CIImage?, output: CIImage,
                               render: (CIImage) -> CGImage?) -> (main: CGImage?, gestures: CGImage?) {
        let main = visible.contains(.mainWindow), gestures = visible.contains(.gestures)
        let colorImage = gestures || (main && alternate == nil) ? render(output) : nil
        if main, let alternate { return (render(alternate), colorImage) }
        return (main ? colorImage : nil, gestures ? colorImage : nil)
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
