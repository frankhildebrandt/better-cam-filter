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
    @Published private(set) var cameras: [CameraChoice] = []
    @Published var selectedCameraID = "" {
        didSet { if oldValue != selectedCameraID { clearKeepStrokes() } }
    }
    @Published private(set) var preview: CGImage?
    @Published private(set) var isRunning = false
    @Published private(set) var isBusy = false
    @Published private(set) var outputConnected = false
    @Published private(set) var error: String?
    @Published private(set) var backgroundName: String?
    @Published private(set) var inputResolution = "–"
    @Published private(set) var framesPerSecond = 0
    @Published private(set) var keepStrokes: [KeepStroke] = []
    @Published var brushRadius = 0.025
    @Published var segmentationMode = SegmentationMode.foregroundObjects {
        didSet { engine.setSegmentationMode(segmentationMode) }
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

    private lazy var engine = CaptureEngine { [weak self] update in
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            self.preview = update.preview
            self.outputConnected = update.outputConnected
            self.error = update.error
            self.inputResolution = update.inputResolution
            self.framesPerSecond = update.framesPerSecond
        }
    }

    func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified
        )
        cameras = discovery.devices
            .filter { $0.uniqueID.caseInsensitiveCompare(CameraConfiguration.deviceID.uuidString) != .orderedSame }
            .map { CameraChoice(id: $0.uniqueID, name: $0.localizedName) }
        if !cameras.contains(where: { $0.id == selectedCameraID }) {
            if isRunning {
                Task { await stop(); error = "Kamera wurde getrennt. Bitte eine Kamera auswählen." }
            }
            selectedCameraID = cameras.first?.id ?? ""
        }
    }

    func start() async {
        guard !isBusy, !isRunning, !selectedCameraID.isEmpty else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard allowed else {
            error = "Bitte Kamerazugriff unter Systemeinstellungen → Datenschutz & Sicherheit → Kamera erlauben."
            return
        }
        do {
            try await engine.start(deviceID: selectedCameraID)
            isRunning = true
        } catch { self.error = error.localizedDescription }
    }

    func stop() async {
        guard !isBusy else { return }
        isBusy = true
        isRunning = false
        isEditingKeepMask = false
        preview = nil
        outputConnected = false
        framesPerSecond = 0
        await engine.stop()
        isBusy = false
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

    func applyBackground(_ image: CGImage, name: String) {
        backgroundImage = image
        backgroundName = name
        backgroundEnabled = true
        error = nil
    }

    func reportError(_ message: String) { error = message }

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

    func shutdown() { engine.shutdown() }
}
