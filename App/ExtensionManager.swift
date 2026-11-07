import Combine
import Foundation
import SystemExtensions

@MainActor
final class ExtensionManager: NSObject, ObservableObject, @preconcurrency OSSystemExtensionRequestDelegate {
    @Published private(set) var status = "Virtuelle Kamera noch nicht aktiviert"
    @Published private(set) var isBusy = false

    func activate() {
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            status = "Bitte BetterCam zuerst nach /Applications kopieren und von dort öffnen."
            return
        }
        isBusy = true
        status = "Aktivierung wird angefragt …"
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: CameraConfiguration.extensionIdentifier, queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        status = "Bitte BetterCam in den Systemeinstellungen unter Kameraerweiterungen erlauben."
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        isBusy = false
        status = result == .completed ? "Kameraerweiterung aktiviert" : "Aktivierung nach dem nächsten Neustart abgeschlossen"
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        isBusy = false
        status = "Aktivierung fehlgeschlagen: \(error.localizedDescription)"
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }
}
