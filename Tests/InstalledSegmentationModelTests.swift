import Foundation
import Testing
@testable import BetterCamCore

struct InstalledSegmentationModelTests {
    @Test func importedModelsRemainSelectableAfterReloadWithoutOriginalFiles() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let first = try store.importModel(from: fixture.source, displayName: "Kompakt", catalogID: "compact")
        let second = try store.importModel(from: fixture.compiled, displayName: "Details", catalogID: "detail")
        fixture.remove()

        let reloaded = try SegmentationModelStore(root: store.directory)
        let installed = try reloaded.installedModels()
        #expect(installed.count == 2)
        let compact = try #require(installed.first { $0.catalogID == "compact" })
        #expect(compact.name == "Kompakt")
        #expect(compact.modelURL == first.customModelURL)
        #expect(try reloaded.load() == second)
        let selected = try reloaded.select(compact)
        #expect(selected.provider == .custom)
        #expect(selected.customModelURL == first.customModelURL)
        #expect(selected.customModelName == "Kompakt")
        #expect(try reloaded.load() == selected)
        try CustomForegroundSegmenter.validate(modelURL: compact.modelURL)
    }

    @Test func legacyActiveModelAppearsWithoutSidecarAndDoesNotDuplicateRegisteredModels() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let imported = try store.importModel(from: fixture.source)
        let modelURL = try #require(imported.customModelURL)
        let sidecar = modelURL.deletingPathExtension().appendingPathExtension("json")
        #expect(try store.installedModels().count == 1)
        try FileManager.default.removeItem(at: sidecar)

        var apple = imported
        apple.provider = .apple
        try store.save(apple)
        let installed = try store.installedModels()
        #expect(installed.count == 1)
        #expect(installed.first?.catalogID == nil)
        #expect(installed.first?.modelURL == modelURL)
        #expect(installed.first?.name == imported.customModelName)
    }

    @Test func staleAndExternalEntriesCannotBeSelectedOrListed() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.save(SegmentationConfiguration())
        let models = store.directory.appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let external = InstalledSegmentationModel(id: id, catalogID: "invalid", name: "Outside",
            modelURL: store.directory.appendingPathComponent("\(id).mlmodelc"))
        try FileManager.default.createDirectory(at: external.modelURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(external).write(to: models.appendingPathComponent("\(id).json"))
        #expect(throws: SegmentationModelStoreError.self) { try store.select(external) }

        let staleID = UUID().uuidString
        let stale = InstalledSegmentationModel(id: staleID, catalogID: nil, name: "Missing",
            modelURL: models.appendingPathComponent("\(staleID).mlmodelc"))
        try JSONEncoder().encode(stale).write(to: models.appendingPathComponent("\(staleID).json"))
        #expect(throws: SegmentationModelStoreError.self) { try store.select(stale) }
        #expect(try store.installedModels().isEmpty)
        #expect(try store.load().provider == .apple)
    }

    @Test func failedImportDoesNotAddLibraryEntryOrChangeSelection() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let selected = try store.importModel(from: fixture.source, displayName: "Aktiv", catalogID: "active")
        let before = try store.installedModels()
        let source = store.directory.appendingPathComponent("broken.mlmodelc")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        #expect(throws: (any Error).self) {
            try store.importModel(from: source, displayName: "Defekt", catalogID: "broken")
        }
        #expect(try store.installedModels() == before)
        #expect(try store.load() == selected)
    }

    @Test func failedSelectionCommitRollsBackCompiledCopyAndSidecar() throws {
        let store = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(at: store.directory.appendingPathComponent("configuration.json"),
                                                withIntermediateDirectories: true)
        #expect(throws: (any Error).self) {
            try store.importModel(from: fixture.source, displayName: "Rollback", catalogID: "rollback")
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: store.directory.appendingPathComponent("Models").path)
        #expect(files.isEmpty)
    }

    private func temporaryStore() throws -> SegmentationModelStore {
        try SegmentationModelStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
}
