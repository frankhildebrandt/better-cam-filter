import Combine
import Foundation
import SwiftUI

/// Exercises the real controller and SwiftUI writeback without opening a camera.
@main
enum VerifyCameraSettings {
    @MainActor
    static func main() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.data(forKey: "outputConfiguration")
        defer {
            if let previous { defaults.set(previous, forKey: "outputConfiguration") }
            else { defaults.removeObject(forKey: "outputConfiguration") }
        }

        let camera = CameraModel()
        var changes = 0
        let observation = camera.objectWillChange.sink { changes += 1 }
        defer { observation.cancel() }
        let binding = Binding(get: { camera.outputConfiguration }, set: { camera.outputConfiguration = $0 })

        binding.frameRate.wrappedValue = 60
        precondition(camera.outputConfiguration.frameRate == 60)
        precondition(CameraModel().outputConfiguration == camera.outputConfiguration)

        for resolution in OutputResolution.allCases {
            binding.resolution.wrappedValue = resolution
            for rate in OutputConfiguration.frameRates {
                binding.frameRate.wrappedValue = rate
                precondition(camera.outputConfiguration == OutputConfiguration(resolution: resolution, frameRate: rate))
                let saved = try JSONDecoder().decode(OutputConfiguration.self,
                                                     from: defaults.data(forKey: "outputConfiguration")!)
                precondition(saved == camera.outputConfiguration)
            }
        }

        binding.frameRate.wrappedValue = -1
        precondition(camera.outputConfiguration.frameRate == 30)
        let beforeUnchangedWrite = changes
        binding.wrappedValue = binding.wrappedValue
        precondition(changes == beforeUnchangedWrite)
        precondition(changes > 0 && changes <= 26)
        print("CameraModel settings: 60 FPS, all formats, persistence, invalid rates and notifications passed.")
    }
}
