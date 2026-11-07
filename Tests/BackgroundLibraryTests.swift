import Foundation
import Testing
@testable import BackgroundKit

struct BackgroundLibraryTests {
    @Test func generatedImagesSurviveReloadWithoutOverwritingEarlierImages() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(try store.load().isEmpty)
        let first = try #require(store.save(Data([1, 2]), name: "Studio").first)
        let second = try #require(store.save(Data([3, 4]), name: "Studio").first)

        let reloaded = try BackgroundLibraryStore(directory: store.directory).load()
        #expect(reloaded.map(\.id) == [second.id, first.id])
        #expect(reloaded.map(\.name) == ["Studio", "Studio"])
        #expect(try Data(contentsOf: store.imageURL(first)) == Data([1, 2]))
        #expect(try Data(contentsOf: store.imageURL(second)) == Data([3, 4]))
    }

    @Test func legacyBackgroundIsImportedOnceAndRetainedWhenAddingImages() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let legacy = store.directory.appendingPathComponent("last-background.png")
        let data = Data([5, 6])
        try data.write(to: legacy)

        let imported = try #require(store.load().first)
        #expect(try store.load().map(\.id) == [imported.id])
        #expect(try Data(contentsOf: store.imageURL(imported)) == data)
        #expect(try Data(contentsOf: legacy) == data)
        _ = try store.save(Data([7]), name: "Neu")
        #expect(try store.load().last == imported)
        #expect(try store.load().count == 2)
    }

    @Test func libraryImagesRemainAvailableAfterDeletingTheirProfile() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let profiles = BackgroundProfileStore(directory: store.directory)
        let profile = BackgroundProfile(name: "Studio")
        _ = try profiles.save(profile, importing: [])
        let image = try #require(store.save(Data([8]), name: profile.name).first)
        _ = try profiles.delete(profile.id)

        #expect(try store.load() == [image])
        #expect(try Data(contentsOf: store.imageURL(image)) == Data([8]))
    }

    @Test func corruptLibraryIsNotOverwritten() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let entry = try #require(store.save(Data([1]), name: "Studio").first)
        let manifest = store.imageURL(entry).deletingLastPathComponent().appendingPathComponent("library.json")
        let invalid = Data("invalid JSON".utf8)
        try invalid.write(to: manifest)

        #expect(throws: (any Error).self) { try store.save(Data([2]), name: "Neu") }
        #expect(try Data(contentsOf: manifest) == invalid)
        #expect(try Data(contentsOf: store.imageURL(entry)) == Data([1]))
    }

    private func temporaryStore() -> BackgroundLibraryStore {
        BackgroundLibraryStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
}
