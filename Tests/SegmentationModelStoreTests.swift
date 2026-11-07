import Foundation
import Testing
@testable import BetterCamCore

struct SegmentationModelStoreTests {
    @Test func newConfigurationDefaultsToApple() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(try store.load() == SegmentationConfiguration())
        #expect(try store.load().provider == .apple)
    }

    @Test func providerAndImportedModelMetadataSurviveReloadAndAppleSelection() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let model = store.directory.appendingPathComponent("Models/\(UUID().uuidString).mlmodelc")
        try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
        var configuration = SegmentationConfiguration(provider: .custom, customModelURL: model,
                                                       customModelName: "Mein Modell")
        try store.save(configuration)
        #expect(try SegmentationModelStore(root: store.directory).load() == configuration)

        configuration.provider = .apple
        try store.save(configuration)
        let reloaded = try store.load()
        #expect(reloaded.provider == .apple)
        #expect(reloaded.customModelURL == model)
        #expect(reloaded.customModelName == "Mein Modell")
    }

    @Test func customSelectionRequiresAnExistingOwnedCompiledDirectory() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(throws: SegmentationModelStoreError.self) {
            try store.save(SegmentationConfiguration(provider: .custom))
        }
        let missing = store.directory.appendingPathComponent("Models/\(UUID().uuidString).mlmodelc")
        #expect(throws: SegmentationModelStoreError.self) {
            try store.save(SegmentationConfiguration(provider: .custom, customModelURL: missing))
        }
        let external = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mlmodelc")
        #expect(throws: SegmentationModelStoreError.self) {
            try store.save(SegmentationConfiguration(provider: .custom, customModelURL: external))
        }
    }

    @Test func invalidImportLeavesStoredSelectionAndOriginalFileUntouched() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let original = SegmentationConfiguration()
        try store.save(original)
        let source = store.directory.appendingPathComponent("source.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let data = Data("not a model".utf8)
        let originalFile = source.appendingPathComponent("invalid.bin")
        try data.write(to: originalFile)

        #expect(throws: (any Error).self) { try store.importModel(from: source) }
        #expect(try store.load() == original)
        #expect(try Data(contentsOf: originalFile) == data)
        let models = store.directory.appendingPathComponent("Models")
        #expect(try FileManager.default.contentsOfDirectory(atPath: models.path).isEmpty)
    }

    @Test func unsupportedFilesCannotReplaceTheCurrentConfiguration() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.save(SegmentationConfiguration())
        #expect(throws: SegmentationModelStoreError.self) {
            try store.importModel(from: store.directory.appendingPathComponent("model.txt"))
        }
        #expect(try store.load().provider == .apple)
    }

    @Test func corruptOrExternalModelMetadataIsRejectedOnLoad() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let manifest = store.directory.appendingPathComponent("configuration.json")
        try Data("invalid JSON".utf8).write(to: manifest)
        #expect(throws: (any Error).self) { try store.load() }
        let configuration = SegmentationConfiguration(provider: .custom,
            customModelURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mlmodelc"))
        try JSONEncoder().encode(configuration).write(to: manifest)
        #expect(throws: SegmentationModelStoreError.self) { try store.load() }
    }

    @Test(arguments: [false, true])
    func importedModelWorksAfterDeletingItsOriginal(compiledInput: Bool) throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let source = compiledInput ? fixture.compiled : fixture.source
        let imported = try store.importModel(from: source)
        fixture.remove()

        #expect(imported.provider == .custom)
        #expect(imported.customModelName == source.deletingPathExtension().lastPathComponent)
        let storedURL = try #require(imported.customModelURL)
        #expect(storedURL != fixture.compiled)
        try CustomForegroundSegmenter.validate(modelURL: storedURL)
        #expect(try SegmentationModelStore(root: store.directory).load() == imported)
    }

    @Test(arguments: [false, true])
    func validReplacementCanRecoverCorruptOrMissingConfiguration(corruptJSON: Bool) throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.save(SegmentationConfiguration())
        let missing = store.directory.appendingPathComponent("Models/\(UUID().uuidString).mlmodelc")
        let broken = SegmentationConfiguration(provider: .custom, customModelURL: missing)
        let badData = try corruptJSON ? Data("invalid JSON".utf8) : JSONEncoder().encode(broken)
        let manifest = store.directory.appendingPathComponent("configuration.json")
        try badData.write(to: manifest)
        #expect(throws: (any Error).self) { try store.load() }

        let invalid = store.directory.appendingPathComponent("invalid.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: invalid, withIntermediateDirectories: true)
        #expect(throws: (any Error).self) { try store.importModel(from: invalid) }
        #expect(try Data(contentsOf: manifest) == badData)

        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let imported = try store.importModel(from: fixture.source)
        #expect(imported.provider == .custom)
        #expect(try store.load() == imported)
    }

    private func temporaryStore() throws -> SegmentationModelStore {
        try SegmentationModelStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
}
