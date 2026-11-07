import Combine
import Foundation

@MainActor
final class SegmentationSettingsModel: ObservableObject {
    @Published private(set) var configuration = SegmentationConfiguration()
    @Published private(set) var isImporting = false
    @Published private(set) var error: String?
    private var store: SegmentationModelStore?

    init() {
        do {
            let store = try SegmentationModelStore()
            self.store = store
            configuration = try store.load()
        } catch { self.error = error.localizedDescription }
    }

    func select(_ provider: SegmentationProvider) {
        guard !isImporting, let store else { return }
        var updated = configuration
        updated.provider = provider
        do {
            try store.save(updated)
            configuration = updated
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func importModel(_ url: URL) async {
        guard !isImporting, let store else { return }
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            configuration = try await Task.detached(priority: .userInitiated) {
                try store.importModel(from: url)
            }.value
        } catch { self.error = error.localizedDescription }
    }

    func reportImportError(_ error: Error) {
        let failure = error as NSError
        guard failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError else { return }
        self.error = error.localizedDescription
    }
}
