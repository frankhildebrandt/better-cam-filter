import Foundation
import Testing
@testable import BetterCamCore

struct GestureSettingsStoreTests {
    @Test func selectionsAndExplicitlyEmptySlotsSurviveRelaunch() throws {
        let suite = "BetterCamGestureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var configuration = GestureConfiguration()
        configuration.enabled = true
        configuration.assign(.pawFive, to: .doubleOpenPalm)
        configuration.assign(nil, to: .peace)
        GestureSettingsStore.save(configuration, to: defaults)
        let restored = GestureSettingsStore.load(from: defaults)
        #expect(restored == configuration)
        #expect(restored.reaction(for: .peace) == nil)
        #expect(restored.reaction(for: .doubleOpenPalm) == .pawFive)
    }

    @Test func corruptStorageFallsBackToDisabledDefaults() throws {
        let suite = "BetterCamGestureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid JSON".utf8), forKey: GestureSettingsStore.key)
        #expect(GestureSettingsStore.load(from: defaults) == GestureConfiguration())
    }
}
