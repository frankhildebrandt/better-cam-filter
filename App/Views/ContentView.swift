import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var extensionManager: ExtensionManager
    @ObservedObject var backgrounds: BackgroundModel
    @ObservedObject var segmentationSettings: SegmentationSettingsModel
    @State private var choosingBackground = false
    @State private var showingGenerator = false
    @State private var showingLibrary = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 10) {
                            Image(nsImage: NSApplication.shared.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BetterCam").font(.headline)
                                Text("Dein Bild. Dein Hintergrund.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        cameraControls
                        Divider()
                        BackgroundControls(camera: camera, backgrounds: backgrounds,
                                           choosingBackground: $choosingBackground, showingGenerator: $showingGenerator,
                                           showingLibrary: $showingLibrary)
                    }
                    .padding(20)
                }
                Divider()
                SettingsLink { Label("Einstellungen …", systemImage: "gearshape") }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .help("Kamera, Bilderkennung und Ausgabe konfigurieren (⌘,)")
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 340)
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(camera.previewMask && camera.backgroundEnabled && !camera.isEditingKeepMask
                             ? "Vorschau der Maske" : "Dein Kamera-Ausgang").font(.title2.bold())
                        Text("So wird dein Bild an andere Apps weitergegeben.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(camera.isRunning ? "Live" : "Gestoppt", systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(camera.isRunning ? .green : .secondary)
                }
                PreviewView(image: camera.preview, isRunning: camera.isRunning)
                    .overlay {
                        if camera.isEditingKeepMask {
                            KeepMaskOverlay(camera: camera).clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                HStack {
                    Label(camera.outputConfiguration.summary, systemImage: "video")
                    Spacer()
                    Text(camera.isRunning ? "Aktuell \(camera.framesPerSecond) FPS · BetterCam" : "Ausgang: BetterCam")
                        .monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
                if camera.isEditingKeepMask {
                    Label("Original zum Markieren · der Kamera-Ausgang bleibt gefiltert", systemImage: "paintbrush.pointed")
                        .font(.caption).foregroundStyle(.cyan)
                } else if camera.previewMask && camera.backgroundEnabled {
                    Label("Weiß bleibt, Schwarz wird ersetzt · Kamera-Ausgang bleibt gefiltert", systemImage: "circle.lefthalf.filled")
                        .font(.caption).foregroundStyle(.secondary)
                } else if camera.isRunning {
                    Text("Kamera-Eingang: \(camera.inputResolution)").font(.caption).foregroundStyle(.secondary)
                }
                if let error = camera.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
                }
                outputStatus
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(minWidth: 580, minHeight: 540)
        }
        .fileImporter(isPresented: $choosingBackground, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url): backgrounds.importBackground(url, camera: camera)
            case .failure(let error): camera.reportError(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingGenerator) {
            BackgroundGeneratorView(model: backgrounds, camera: camera)
        }
        .sheet(isPresented: $showingLibrary) {
            BackgroundLibraryView(model: backgrounds, camera: camera)
        }
        .task { camera.refreshCameras() }
        .onChange(of: segmentationSettings.configuration, initial: true) { _, configuration in
            camera.setSegmentationConfiguration(configuration)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in camera.refreshCameras() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in camera.refreshCameras() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification)) { _ in
            Task { await camera.stop(); camera.reportError("Die Kamera wurde unterbrochen. Bitte erneut starten.") }
        }
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "video.fill").foregroundStyle(.secondary)
                Text(camera.cameras.first(where: { $0.id == camera.selectedCameraID })?.name ?? "Keine Kamera gefunden")
                    .font(.callout.weight(.medium)).lineLimit(2)
            }
            Button {
                Task { if camera.isRunning { await camera.stop() } else { await camera.start() } }
            } label: {
                HStack {
                    if camera.isBusy { ProgressView().controlSize(.small) }
                    Label(camera.isRunning ? "Kamera stoppen" : "Kamera starten",
                          systemImage: camera.isRunning ? "stop.fill" : "play.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(camera.isBusy || camera.selectedCameraID.isEmpty)
        }
    }

    private var outputStatus: some View {
        Label {
            Text(camera.outputConnected
                 ? "Verbunden. Wähle „BetterCam“ in deiner Video-App."
                 : "Für andere Apps die virtuelle Kamera unter Einstellungen → Ausgabe aktivieren.")
        } icon: {
            Image(systemName: camera.outputConnected ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(camera.outputConnected ? .green : .secondary)
        }
        .font(.callout).padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
