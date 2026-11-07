import Foundation
import Testing
@testable import BackgroundKit

struct BackgroundProfileTests {
    @Test func profilesAndAssetCopiesSurviveReloadAndEditing() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var profile = BackgroundProfile(name: "Studio", prePrompt: "Warme Farben, dezentes Logo")
        let data = Data([1, 2, 3])
        let saved = try store.save(profile, importing: [.init(name: "logo.png", data: data, fileExtension: "png")])
        let reloaded = try store.load()
        #expect(reloaded == saved)
        profile = try #require(reloaded.first)
        let asset = try #require(profile.assets.first)
        let path = try store.assetURL(asset)
        #expect(try Data(contentsOf: path) == data)
        profile.prePrompt = "Kühle Farben"
        _ = try store.save(profile, importing: [])
        #expect(try store.load().count == 1)
        #expect(try store.load().first?.prePrompt == "Kühle Farben")
        #expect(FileManager.default.fileExists(atPath: path.path))
        profile.assets = []
        _ = try store.save(profile, importing: [])
        #expect(!FileManager.default.fileExists(atPath: path.path))
        #expect(try store.delete(profile.id).isEmpty)
        #expect(try store.load().isEmpty)
    }

    @Test func deleteRetainsOtherProfilesAndTheirAssets() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let first = BackgroundProfile(name: "A")
        let second = BackgroundProfile(name: "B")
        _ = try store.save(first, importing: [.init(name: "a.png", data: Data([1]), fileExtension: "png")])
        let profiles = try store.save(second, importing: [.init(name: "b.png", data: Data([2]), fileExtension: "png")])
        let remaining = try store.delete(first.id)
        #expect(remaining.map(\.id) == [second.id])
        let asset = try #require(profiles.last?.assets.first)
        #expect(try Data(contentsOf: store.assetURL(asset)) == Data([2]))
    }

    @Test func corruptManifestIsNotOverwritten() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let path = store.directory.appendingPathComponent("profiles.json")
        let invalid = Data("invalid JSON".utf8)
        try invalid.write(to: path)
        #expect(throws: (any Error).self) { try store.save(BackgroundProfile(name: "New"), importing: []) }
        #expect(try Data(contentsOf: path) == invalid)
    }

    @Test func emptyNameAndPathTraversalAreRejected() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(throws: BackgroundError.self) { try store.save(BackgroundProfile(name: " \n"), importing: []) }
        let asset = BackgroundAsset(id: UUID(), name: "Bad", filename: "../outside.png")
        #expect(throws: BackgroundError.self) { try store.assetURL(asset) }
    }

    private func temporaryStore() -> BackgroundProfileStore {
        BackgroundProfileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
}
