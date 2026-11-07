import CoreImage
import Foundation

/// Opt-in network check of the production downloader, importer and real model adapter.
@main
struct VerifyModelCatalog {
    static func main() async throws {
        guard CommandLine.arguments.count > 1 else {
            print("Usage: verify-model-catalog OUTPUT_DIRECTORY [--all]")
            return
        }
        let store = try SegmentationModelStore(root: URL(fileURLWithPath: CommandLine.arguments[1]))
        let catalog = SegmentationModelCatalog.models.filter {
            CommandLine.arguments.contains("--all") || $0.id == SegmentationModelCatalog.recommendedID
        }
        for model in catalog {
            print("Downloading \(model.title)…")
            let file = try await SegmentationModelDownloader().download(model) { _ in }
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            let configuration = try store.importModel(from: file, displayName: model.title, catalogID: model.id)
            let segmenter = ForegroundSegmenter()
            segmenter.configuration = configuration
            let bounds = CGRect(x: 0, y: 0, width: 160, height: 90)
            let mask = try segmenter.mask(for: CIImage(color: .black).cropped(to: bounds))
            guard mask.extent == bounds else { throw CustomSegmentationError.invalidMask }
            print("\(model.title): size + SHA-256 verified, compiled, predicted; stored copy \(configuration.customModelURL!.lastPathComponent)")
        }
        let reloaded = try SegmentationModelStore(root: store.directory)
        for model in try reloaded.installedModels() {
            let configuration = try reloaded.select(model)
            guard configuration.customModelURL == model.modelURL else { throw CustomSegmentationError.missingModel }
        }
        print("Library reload and model selection verified.")
    }
}
