import CoreML
import Foundation

enum SegmentationModelStoreError: LocalizedError {
    case unsupportedFile
    case invalidModelLocation
    case missingCustomModel

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "Bitte ein Core-ML-Modell als .mlmodel, .mlpackage oder .mlmodelc auswählen."
        case .invalidModelLocation: "Die gespeicherte Modelldatei gehört nicht zur BetterCam-Modellbibliothek. Bitte erneut importieren."
        case .missingCustomModel: "Bitte zuerst ein Custom-Modell importieren. Die gespeicherte Modelldatei ist nicht verfügbar."
        }
    }
}

struct SegmentationModelStore: Sendable {
    let directory: URL

    private var models: URL { directory.appendingPathComponent("Models", isDirectory: true) }
    private var manifest: URL { directory.appendingPathComponent("configuration.json") }

    init(root: URL? = nil) throws {
        if let root {
            directory = root.standardizedFileURL
        } else {
            directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
                .appendingPathComponent("BetterCam/Segmentation", isDirectory: true)
        }
    }

    func load() throws -> SegmentationConfiguration {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return SegmentationConfiguration() }
        let configuration = try JSONDecoder().decode(SegmentationConfiguration.self, from: Data(contentsOf: manifest))
        try check(configuration)
        return configuration
    }

    func save(_ configuration: SegmentationConfiguration) throws {
        try check(configuration)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(configuration).write(to: manifest, options: .atomic)
    }

    /// List durable model copies, retaining an active model imported before the library existed.
    func installedModels() throws -> [InstalledSegmentationModel] {
        var installed = [String: InstalledSegmentationModel]()
        if FileManager.default.fileExists(atPath: models.path) {
            let files = try FileManager.default.contentsOfDirectory(at: models, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let model = try? JSONDecoder().decode(InstalledSegmentationModel.self, from: data),
                      model.id == file.deletingPathExtension().lastPathComponent,
                      (try? check(model)) != nil else { continue }
                installed[model.id] = model
            }
        }
        if let current = try? load(), let url = current.customModelURL {
            let id = url.deletingPathExtension().lastPathComponent
            let legacy = InstalledSegmentationModel(id: id, catalogID: nil,
                name: current.customModelName ?? "Custom-Modell", modelURL: url)
            if installed[id] == nil, (try? check(legacy)) != nil { installed[id] = legacy }
        }
        return installed.values.sorted {
            $0.name == $1.name ? $0.id < $1.id : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Select a validated owned model copy without downloading or recompiling it.
    func select(_ model: InstalledSegmentationModel) throws -> SegmentationConfiguration {
        try check(model)
        let configuration = SegmentationConfiguration(provider: .custom, customModelURL: model.modelURL,
                                                       customModelName: model.name)
        try save(configuration)
        return configuration
    }

    /// Commit a new selection only after an owned copy compiles, validates and persists successfully.
    func importModel(from url: URL, displayName: String? = nil, catalogID: String? = nil) throws -> SegmentationConfiguration {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let format = url.pathExtension.lowercased()
        guard ["mlmodel", "mlpackage", "mlmodelc"].contains(format) else {
            throw SegmentationModelStoreError.unsupportedFile
        }
        let compiled: URL
        if format == "mlmodelc" { compiled = url }
        else { compiled = try MLModel.compileModel(at: url) }
        defer { if format != "mlmodelc" { try? FileManager.default.removeItem(at: compiled) } }
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let destination = models.appendingPathComponent(id).appendingPathExtension("mlmodelc")
        let sidecar = models.appendingPathComponent(id).appendingPathExtension("json")
        var committed = false
        defer {
            if !committed {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.removeItem(at: sidecar)
            }
        }
        try FileManager.default.copyItem(at: compiled, to: destination)
        try CustomForegroundSegmenter.validate(modelURL: destination)
        let name = displayName ?? url.deletingPathExtension().lastPathComponent
        let installed = InstalledSegmentationModel(id: id, catalogID: catalogID, name: name, modelURL: destination)
        try JSONEncoder().encode(installed).write(to: sidecar, options: .atomic)
        let configuration = SegmentationConfiguration(provider: .custom, customModelURL: destination,
                                                       customModelName: name)
        try save(configuration)
        committed = true
        return configuration
    }

    private func check(_ model: InstalledSegmentationModel) throws {
        guard model.id == model.modelURL.deletingPathExtension().lastPathComponent else {
            throw SegmentationModelStoreError.invalidModelLocation
        }
        try check(SegmentationConfiguration(provider: .custom, customModelURL: model.modelURL))
    }

    private func check(_ configuration: SegmentationConfiguration) throws {
        if let url = configuration.customModelURL {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard url.isFileURL, url.pathExtension == "mlmodelc",
                  UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil,
                  resolved.deletingLastPathComponent() == models.resolvingSymlinksInPath().standardizedFileURL else {
                throw SegmentationModelStoreError.invalidModelLocation
            }
        }
        if configuration.provider == .custom {
            guard let url = configuration.customModelURL,
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                throw SegmentationModelStoreError.missingCustomModel
            }
        }
    }
}
