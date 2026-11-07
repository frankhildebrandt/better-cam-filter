import Combine
import Foundation

@MainActor
final class SegmentationSettingsModel: ObservableObject {
    @Published private(set) var configuration = SegmentationConfiguration()
    @Published private(set) var isImporting = false
    @Published private(set) var installedModels: [InstalledSegmentationModel] = []
    @Published private(set) var downloadingModelID: String?
    @Published private(set) var downloadProgress = 0.0
    @Published private(set) var error: String?
    private var store: SegmentationModelStore?
    private var downloadTask: Task<Void, Never>?

    var isBusy: Bool { isImporting || downloadingModelID != nil }

    init() {
        do {
            let store = try SegmentationModelStore()
            self.store = store
            do { configuration = try store.load() }
            catch { self.error = error.localizedDescription }
            installedModels = try store.installedModels()
        } catch { self.error = error.localizedDescription }
    }

    func select(_ provider: SegmentationProvider) {
        guard !isBusy, let store else { return }
        var updated = configuration
        updated.provider = provider
        do {
            try store.save(updated)
            configuration = updated
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func importModel(_ url: URL) async {
        guard !isBusy, let store else { return }
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            configuration = try await Task.detached(priority: .userInitiated) {
                try store.importModel(from: url)
            }.value
            installedModels = try store.installedModels()
        } catch { self.error = error.localizedDescription }
    }

    func select(_ model: InstalledSegmentationModel) {
        guard !isBusy, let store else { return }
        do {
            configuration = try store.select(model)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func use(_ model: DownloadableSegmentationModel) {
        guard !isBusy, let store else { return }
        if let installed = installedModels.first(where: { $0.catalogID == model.id }) {
            select(installed)
            return
        }
        downloadingModelID = model.id
        downloadProgress = 0
        error = nil
        downloadTask = Task { [weak self] in
            guard let self else { return }
            defer { downloadingModelID = nil; isImporting = false; downloadTask = nil }
            do {
                let file = try await SegmentationModelDownloader().download(model) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard self?.downloadingModelID == model.id else { return }
                        self?.downloadProgress = fraction
                    }
                }
                defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
                try Task.checkCancellation()
                isImporting = true
                configuration = try await Task.detached(priority: .userInitiated) {
                    try store.importModel(from: file, displayName: model.title, catalogID: model.id)
                }.value
                installedModels = try store.installedModels()
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }

    func cancelDownload() {
        guard !isImporting else { return }
        downloadTask?.cancel()
    }

    func reportImportError(_ error: Error) {
        let failure = error as NSError
        guard failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError else { return }
        self.error = error.localizedDescription
    }
}
