import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

struct CameraChoice: Identifiable {
    let id: String
    let name: String
}

@MainActor
final class CameraModel: ObservableObject {
    enum PreviewSource { case mainWindow, gestures }

    @Published private(set) var cameras: [CameraChoice] = []
    @Published var selectedCameraID = UserDefaults.standard.string(forKey: "selectedCameraID") ?? "" {
        didSet {
            UserDefaults.standard.set(selectedCameraID, forKey: "selectedCameraID")
            if oldValue != selectedCameraID { clearKeepStrokes() }
        }
    }
    @Published private(set) var preview: CGImage?
    @Published private(set) var outputPreview: CGImage?
    @Published private(set) var isRunning = false
    @Published private(set) var isBusy = false
    @Published private(set) var outputConnected = false
    @Published private(set) var error: String?
    @Published private(set) var backgroundName: String?
    @Published private(set) var backgroundLibraryID: UUID?
    @Published private(set) var inputResolution = "–"
    @Published private(set) var framesPerSecond = 0
    @Published private(set) var detectedGesture: GestureKind?
    @Published private(set) var gestureError: String?
    @Published var gestureConfiguration = GestureSettingsStore.load() {
        didSet {
            GestureSettingsStore.save(gestureConfiguration)
            engine.setGestureConfiguration(gestureConfiguration)
            detectedGesture = nil
            gestureError = nil
        }
    }
    @Published var outputConfiguration: OutputConfiguration = {
        guard let data = UserDefaults.standard.data(forKey: "outputConfiguration"),
              let saved = try? JSONDecoder().decode(OutputConfiguration.self, from: data) else {
            return OutputConfiguration()
        }
        return saved.sanitized
    }() {
        didSet {
            guard !isRunning, !isBusy else { outputConfiguration = oldValue; return }
            outputConfiguration = outputConfiguration.sanitized
            if let data = try? JSONEncoder().encode(outputConfiguration) {
                UserDefaults.standard.set(data, forKey: "outputConfiguration")
            }
        }
    }
    @Published private(set) var keepStrokes: [KeepStroke] = []
    @Published var brushRadius = 0.025
    @Published var previewMask = UserDefaults.standard.bool(forKey: "previewMask") {
        didSet {
            UserDefaults.standard.set(previewMask, forKey: "previewMask")
            engine.setPreviewMask(previewMask)
        }
    }
    @Published var segmentationMode = SegmentationMode(
        rawValue: UserDefaults.standard.string(forKey: "segmentationMode") ?? ""
    ) ?? .foregroundObjects {
        didSet {
            UserDefaults.standard.set(segmentationMode.rawValue, forKey: "segmentationMode")
            engine.setSegmentationMode(segmentationMode)
        }
    }
    @Published var accessoriesEnabled = (UserDefaults.standard.object(forKey: "accessoriesEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(accessoriesEnabled, forKey: "accessoriesEnabled")
            engine.setAccessoriesEnabled(accessoriesEnabled)
        }
    }
    @Published var isEditingKeepMask = false {
        didSet { engine.setPreviewOriginal(isEditingKeepMask) }
    }
    private var backgroundImage: CGImage?
    @Published var backgroundEnabled = false {
        didSet {
            engine.setBackground(backgroundEnabled ? backgroundImage : nil)
            if !backgroundEnabled { isEditingKeepMask = false }
        }
    }

    private var observations = Set<AnyCancellable>()
    private var previewSource: PreviewSource?
    private var sourceIsActive = false
    private var automaticStartSuppressed = false
    private var isShuttingDown = false
    private lazy var demand = VirtualCameraDemand { [weak self] active in
        guard let self else { return }
        self.sourceIsActive = active
        if !active { self.automaticStartSuppressed = false }
        self.reconcileCapture()
    }

    private lazy var engine = CaptureEngine { [weak self] update in
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            self.preview = update.preview
            self.outputPreview = update.outputPreview
            self.outputConnected = update.outputConnected
            self.error = update.error
            self.inputResolution = update.inputResolution
            self.framesPerSecond = update.framesPerSecond
            self.detectedGesture = update.detectedGesture
            self.gestureError = update.gestureError
        }
    }

    func observeCameraUsage() {
        refreshCameras()
        let notifications = NotificationCenter.default
        notifications.publisher(for: AVCaptureDevice.wasConnectedNotification)
            .merge(with: notifications.publisher(for: AVCaptureDevice.wasDisconnectedNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshCameras() }
            .store(in: &observations)
        notifications.publisher(for: AVCaptureSession.runtimeErrorNotification, object: engine.captureSession)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.stop()
                self?.error = "Die Kamera wurde unterbrochen. Bitte erneut starten."
            }
            .store(in: &observations)
        demand.start()
    }

    func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified
        )
        cameras = discovery.devices
            .filter { $0.uniqueID.caseInsensitiveCompare(CameraConfiguration.deviceID.uuidString) != .orderedSame }
            .map { CameraChoice(id: $0.uniqueID, name: $0.localizedName) }
        if !cameras.contains(where: { $0.id == selectedCameraID }) {
            if !selectedCameraID.isEmpty, isRunning || isBusy {
                stop()
                error = "Kamera wurde getrennt. Bitte eine Kamera auswählen."
            }
            selectedCameraID = cameras.first?.id ?? ""
        }
        reconcileCapture()
    }

    func startPreview(_ source: PreviewSource) {
        previewSource = source
        automaticStartSuppressed = false
        reconcileCapture()
    }

    func endPreview(_ source: PreviewSource) {
        guard previewSource == source else { return }
        previewSource = nil
        reconcileCapture()
    }

    func stop() {
        previewSource = nil
        // A manual stop applies until the current use of the virtual camera ends.
        automaticStartSuppressed = sourceIsActive
        reconcileCapture()
    }

    private var wantsCapture: Bool {
        !isShuttingDown && !selectedCameraID.isEmpty
            && (previewSource != nil || (sourceIsActive && !automaticStartSuppressed))
    }

    private func reconcileCapture() {
        guard !isBusy, wantsCapture != isRunning else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            // Demand and preview visibility can change while permissions or AVFoundation are pending.
            while wantsCapture != isRunning {
                if wantsCapture { await startCapture() } else { await stopCapture() }
            }
        }
    }

    private func startCapture() async {
        error = nil
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard wantsCapture else { return }
        guard allowed else {
            stop()
            error = "Bitte Kamerazugriff unter Systemeinstellungen → Datenschutz & Sicherheit → Kamera erlauben."
            return
        }
        do {
            engine.setPreviewMask(previewMask)
            engine.setGestureConfiguration(gestureConfiguration)
            try await engine.start(deviceID: selectedCameraID, configuration: outputConfiguration)
            isRunning = true
        } catch {
            stop()
            self.error = error.localizedDescription
        }
    }

    private func stopCapture() async {
        isRunning = false
        isEditingKeepMask = false
        preview = nil
        outputPreview = nil
        outputConnected = false
        framesPerSecond = 0
        detectedGesture = nil
        gestureError = nil
        await engine.stop()
    }

    func loadBackground(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            error = "Das Hintergrundbild konnte nicht geöffnet werden."
            return
        }
        applyBackground(cgImage, name: url.lastPathComponent)
    }

    func applyBackground(_ image: CGImage, name: String, libraryID: UUID? = nil) {
        backgroundImage = image
        backgroundName = name
        backgroundLibraryID = libraryID
        backgroundEnabled = true
        error = nil
    }

    func reportError(_ message: String) { error = message }

    func assignReaction(_ reaction: ReactionKind?, to gesture: GestureKind) {
        gestureConfiguration.assign(reaction, to: gesture)
    }

    func previewReaction(for gesture: GestureKind) {
        guard isRunning, let reaction = gestureConfiguration.reaction(for: gesture) else { return }
        engine.previewReaction(reaction, for: gesture)
    }

    func setSegmentationConfiguration(_ configuration: SegmentationConfiguration) {
        engine.setSegmentationConfiguration(configuration)
        engine.setSegmentationMode(segmentationMode)
        engine.setAccessoriesEnabled(accessoriesEnabled)
    }

    func addKeepStroke(_ stroke: KeepStroke) {
        keepStrokes.append(stroke)
        updateKeepMask()
    }

    func undoKeepStroke() {
        guard !keepStrokes.isEmpty else { return }
        keepStrokes.removeLast()
        updateKeepMask()
    }

    func clearKeepStrokes() {
        keepStrokes.removeAll()
        updateKeepMask()
    }

    private func updateKeepMask() { engine.setKeepMask(KeepMask.render(keepStrokes)) }

    func shutdown() {
        isShuttingDown = true
        observations.removeAll()
        demand.stop()
        engine.shutdown()
    }
}
