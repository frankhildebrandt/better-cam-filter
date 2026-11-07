import AppKit
import SwiftUI

@main
struct BetterCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var camera = CameraModel()
    @StateObject private var extensionManager = ExtensionManager()
    @StateObject private var backgrounds = BackgroundModel()
    @StateObject private var segmentationSettings = SegmentationSettingsModel()

    var body: some Scene {
        WindowGroup {
            ContentView(camera: camera, extensionManager: extensionManager, backgrounds: backgrounds,
                        segmentationSettings: segmentationSettings)
                .onAppear { delegate.onTerminate = { camera.shutdown(); backgrounds.shutdown() } }
        }
        .defaultSize(width: 1080, height: 680)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
        Settings {
            ConfigurationView(settings: segmentationSettings, camera: camera,
                              extensionManager: extensionManager, backgrounds: backgrounds)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { onTerminate?() }
}
