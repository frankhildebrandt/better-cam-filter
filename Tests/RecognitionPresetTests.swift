import Foundation
import Testing
@testable import BetterCamCore

struct RecognitionPresetTests {
    @Test(arguments: RecognitionPreset.allCases)
    func presetsConfigureTheActiveModelAndRetainImportedProfiles(_ preset: RecognitionPreset) throws {
        let url = URL(fileURLWithPath: "/tmp/imported.mlmodelc")
        var custom = SegmentationConfiguration(provider: .custom, customModelURL: url)
        custom.maskSettings = .cleanEdges
        custom.inferenceSettings = ModelInferenceSettings(computeUnits: .cpuOnly, inputScaling: .aspectFit)
        custom.appleAccessories.mode = .person
        custom.appleAccessories.enabled = false
        custom.appleSettings.quality = .fast
        custom.appleSettings.analysisWidth = 256

        let selected = preset.applying(to: custom)
        #expect(selected.appleSettings.quality == .accurate)
        #expect(selected.appleSettings.analysisWidth == 768)
        let expectedDetail: AccessoryDetail = switch preset {
        case .videoCall: .standard
        case .balancedMicrophone: .fine
        case .fineCables, .freestandingMicrophone: .veryFine
        }
        #expect(selected.appleSettings.accessoryDetail == expectedDetail)
        if preset == .freestandingMicrophone {
            #expect(selected.provider == .appleObjects)
            #expect(selected.maskSettings == .microphoneSetup)
            #expect(selected.appleAccessories == custom.appleAccessories)
        } else {
            #expect(selected.provider == .apple)
            #expect(selected.appleAccessories.isActive)
            #expect(selected.maskSettings == .original)
        }
        let data = try JSONEncoder().encode(selected)
        var restored = try JSONDecoder().decode(SegmentationConfiguration.self, from: data)
        #expect(RecognitionPreset.matching(restored) == preset)
        restored.provider = .custom
        #expect(RecognitionPreset.matching(restored) == nil)
        #expect(restored.customModelURL == url)
        #expect(restored.maskSettings == custom.maskSettings)
        #expect(restored.inferenceSettings == custom.inferenceSettings)
    }

    @Test func pickerTracksManualChangesAndRecognizesMatchingValuesAgain() {
        var settings = SegmentationConfiguration()
        #expect(RecognitionPreset.matching(settings) == .videoCall)
        settings.appleSettings.accessoryDetail = .veryFine
        #expect(RecognitionPreset.matching(settings) == .fineCables)
        settings.appleAccessories.enabled = false
        #expect(RecognitionPreset.matching(settings) == nil)
        settings.appleAccessories = .init()
        settings.maskSettings = .cleanEdges
        #expect(RecognitionPreset.matching(settings) == nil)
        settings = RecognitionPreset.fineCables.applying(to: settings)
        #expect(RecognitionPreset.matching(settings) == .fineCables)
        settings.appleSettings.revision = 9
        #expect(RecognitionPreset.matching(settings) == nil)
    }

    @Test func legacyAccessoryChoicesSurviveUntilAnExplicitPresetIsSaved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = AppleAccessorySelection(mode: .person, enabled: false)
        let store = try SegmentationModelStore(root: root, legacyAppleAccessories: legacy)
        #expect(try store.load().appleAccessories == legacy)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let old = Data(#"{"provider":"apple","appleSettings":{"analysisWidth":512}}"#.utf8)
        try old.write(to: root.appendingPathComponent("configuration.json"))
        let migrated = try store.load()
        #expect(migrated.appleAccessories == legacy)
        #expect(migrated.appleSettings.analysisWidth == 512)
        #expect(RecognitionPreset.matching(migrated) == nil)
        try store.save(RecognitionPreset.fineCables.applying(to: migrated))
        let relaunched = try SegmentationModelStore(root: root, legacyAppleAccessories: legacy).load()
        #expect(RecognitionPreset.matching(relaunched) == .fineCables)
    }
}
