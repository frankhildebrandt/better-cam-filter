import AppKit
import Combine
import SwiftUI

@main
struct BetterCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("BetterCam", id: "main") {
            ContentView(camera: delegate.camera, backgrounds: delegate.backgrounds)
        }
        .defaultSize(width: 1080, height: 680)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings {
            ConfigurationView(settings: delegate.segmentationSettings, camera: delegate.camera,
                              extensionManager: delegate.extensionManager, backgrounds: delegate.backgrounds)
        }
        MenuBarExtra {
            BetterCamMenu(camera: delegate.camera)
        } label: {
            BetterCamMenuLabel(camera: delegate.camera)
        }
    }
}

private struct BetterCamMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var camera: CameraModel

    var body: some View {
        Button("BetterCam öffnen") {
            openWindow(id: "main")
            NSApp.activate()
        }
        SettingsLink { Text("Einstellungen …") }
        Divider()
        Text(camera.isBusy ? "Kamera wird umgeschaltet …" : camera.isRunning ? "Kamera aktiv" : "Kamera aus")
        if let error = camera.error { Text(error) }
        if camera.isRunning {
            Button("Kamera stoppen") { camera.stop() }
                .disabled(camera.isBusy)
        }
        Divider()
        Button("BetterCam beenden") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct BetterCamMenuLabel: View {
    @ObservedObject var camera: CameraModel

    var body: some View {
        Label("BetterCam", systemImage: camera.isRunning ? "video.fill" : "video")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let camera = CameraModel()
    let extensionManager = ExtensionManager()
    let backgrounds = BackgroundModel()
    let segmentationSettings = SegmentationSettingsModel()
    private var segmentationObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        segmentationObservation = segmentationSettings.$configuration.sink { [weak camera] in
            camera?.setSegmentationConfiguration($0)
        }
        camera.observeCameraUsage()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        camera.endPreview(.mainWindow)
        camera.endPreview(.gestures)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        camera.shutdown()
        backgrounds.shutdown()
    }
}
