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

    /// Commit a new selection only after an owned copy compiles, validates and persists successfully.
    func importModel(from url: URL) throws -> SegmentationConfiguration {
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
        let destination = models.appendingPathComponent(UUID().uuidString).appendingPathExtension("mlmodelc")
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: destination) } }
        try FileManager.default.copyItem(at: compiled, to: destination)
        try CustomForegroundSegmenter.validate(modelURL: destination)
        let configuration = SegmentationConfiguration(provider: .custom, customModelURL: destination,
                                                       customModelName: url.deletingPathExtension().lastPathComponent)
        try save(configuration)
        committed = true
        return configuration
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
