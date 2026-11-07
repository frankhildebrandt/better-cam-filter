import Foundation

enum GestureSettingsStore {
    static let key = "gestureConfiguration"

    static func load(from defaults: UserDefaults = .standard) -> GestureConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(GestureConfiguration.self, from: data) else {
            return GestureConfiguration()
        }
        return configuration
    }

    static func save(_ configuration: GestureConfiguration, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: key)
    }
}
