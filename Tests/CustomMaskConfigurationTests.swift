import Foundation
import Testing
@testable import BetterCamCore

struct CustomMaskConfigurationTests {
    @Test func oldConfigurationWithoutProfilesRemainsReadable() throws {
        let data = Data(#"{"provider":"custom","customModelURL":"file:///tmp/legacy.mlmodelc","customModelName":"Legacy"}"#.utf8)
        let configuration = try JSONDecoder().decode(SegmentationConfiguration.self, from: data)
        #expect(configuration.provider == .custom)
        #expect(configuration.customModelName == "Legacy")
        #expect(!configuration.hasMaskSettings)
        #expect(configuration.maskSettings == .balanced)
    }

    @Test func modelSettingsSurviveImportingAndSwitchingOtherModelsAndApple() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SegmentationModelStore(root: root)
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        var small = try store.importModel(from: fixture.source, displayName: "Klein", catalogID: "u2netp")
        #expect(small.maskSettings == .detailed)
        small.maskSettings = CustomMaskSettings(threshold: 0.4, edgeInset: -2, personSupport: true)
        try store.save(small)

        var full = try store.importModel(from: fixture.source, displayName: "Groß", catalogID: "u2net")
        #expect(full.maskSettings == .balanced)
        full.maskSettings = .cleanEdges
        try store.save(full)
        let installed = try store.installedModels()
        let smallModel = try #require(installed.first { $0.catalogID == "u2netp" })
        let fullModel = try #require(installed.first { $0.catalogID == "u2net" })
        let reloaded = try SegmentationModelStore(root: root)
        var selectedSmall = try reloaded.select(smallModel)
        #expect(selectedSmall.maskSettings == small.maskSettings)
        selectedSmall.provider = .apple
        try reloaded.save(selectedSmall)
        #expect(try reloaded.select(fullModel).maskSettings == .cleanEdges)
        #expect(try reloaded.select(smallModel).maskSettings.personSupport)
        #expect(try reloaded.select(smallModel).maskSettings.edgeInset == -2)
    }

    @Test func manualAlphaModelDefaultsToItsUnmodifiedOutput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SegmentationModelStore(root: root)
        let fixture = try CustomModelFixture.make()
        defer { fixture.remove() }
        let imported = try store.importModel(from: fixture.source)
        #expect(imported.maskSettings == .original)
        #expect(try store.load().maskSettings == .original)
    }
}
