import Foundation
import Testing
import Vision
@testable import BetterCamCore

struct CustomMaskConfigurationTests {
    @Test func partialRecognitionSettingsKeepDefaultsAndSanitizeInvalidWidths() throws {
        let data = Data(#"{"provider":"apple","appleSettings":{"quality":"balanced","analysisWidth":-200},"inferenceProfiles":{"custom":{"computeUnits":"cpuOnly"}}}"#.utf8)
        var configuration = try JSONDecoder().decode(SegmentationConfiguration.self, from: data)
        #expect(configuration.appleSettings.quality == .balanced)
        #expect(configuration.appleSettings.analysisWidth == 128)
        #expect(configuration.appleSettings.revision == 0)
        #expect(!configuration.appleSettings.preferBackgroundProcessing)
        configuration.provider = .custom
        #expect(configuration.inferenceSettings.computeUnits == .cpuOnly)
        #expect(configuration.inferenceSettings.inputScaling == .stretch)
    }

    @Test func appleAndEachCustomModelKeepSeparateMaskAndInferenceProfiles() throws {
        let url = URL(fileURLWithPath: "/tmp/first.mlmodelc")
        var configuration = SegmentationConfiguration(provider: .custom, customModelURL: url)
        configuration.maskSettings = .detailed
        configuration.inferenceSettings = ModelInferenceSettings(computeUnits: .cpuOnly, inputScaling: .aspectFit)
        configuration.provider = .apple
        #expect(configuration.maskSettings == .original)
        #expect(!configuration.hasMaskSettings)
        configuration.maskSettings = .cleanEdges
        configuration.appleSettings.quality = .fast
        configuration.appleSettings.analysisWidth = 512
        configuration.provider = .custom
        #expect(configuration.maskSettings == .detailed)
        #expect(configuration.inferenceSettings.computeUnits == .cpuOnly)
        configuration.customModelURL = URL(fileURLWithPath: "/tmp/second.mlmodelc")
        #expect(configuration.inferenceSettings == ModelInferenceSettings())
        configuration.inferenceSettings.inputScaling = .aspectFill
        let restored = try JSONDecoder().decode(SegmentationConfiguration.self, from: JSONEncoder().encode(configuration))
        #expect(restored == configuration)
        configuration.provider = .apple
        #expect(configuration.maskSettings == .cleanEdges)
        #expect(configuration.appleSettings.quality == .fast)
    }

    @Test func oldAppleConfigurationRetainsUnmodifiedMaskEvenWhenCustomModelWasPreviouslySelected() throws {
        let data = Data(#"{"provider":"apple","customModelURL":"file:///tmp/legacy.mlmodelc","maskProfiles":{"legacy.mlmodelc":{"threshold":0.8}}}"#.utf8)
        let configuration = try JSONDecoder().decode(SegmentationConfiguration.self, from: data)
        #expect(configuration.maskSettings == .original)
        #expect(configuration.appleSettings.analysisWidth == 768)
        #expect(configuration.appleSettings.quality == .accurate)
    }

    @Test func appleRequestActuallyUsesChosenQualityRevisionAndScheduling() {
        var settings = AppleRecognitionSettings()
        settings.quality = .fast
        settings.preferBackgroundProcessing = true
        settings.revision = VNGeneratePersonSegmentationRequest.supportedRevisions.first ?? 0
        let request = ForegroundSegmenter.makeRequest(settings: settings)
        #expect(request.qualityLevel == .fast)
        #expect(request.preferBackgroundProcessing)
        if settings.revision > 0 { #expect(request.revision == settings.revision) }
        settings.revision = Int.max
        #expect(VNGeneratePersonSegmentationRequest.supportedRevisions.contains(
            ForegroundSegmenter.makeRequest(settings: settings).revision
        ))
    }

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
