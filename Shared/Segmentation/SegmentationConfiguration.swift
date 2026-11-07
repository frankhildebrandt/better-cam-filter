import Foundation

enum SegmentationProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple, custom

    var id: Self { self }
    var title: String {
        switch self {
        case .apple: "Apple Vision"
        case .custom: "Custom-Modell"
        }
    }
}

struct SegmentationConfiguration: Codable, Equatable, Sendable {
    var provider: SegmentationProvider = .apple
    var customModelURL: URL?
    var customModelName: String?
    var maskProfiles: [String: CustomMaskSettings] = [:]
    var hasMaskSettings: Bool { maskProfiles[profileKey] != nil }

    var maskSettings: CustomMaskSettings {
        get { (maskProfiles[profileKey] ?? .balanced).sanitized }
        set { maskProfiles[profileKey] = newValue.sanitized }
    }

    private var profileKey: String { customModelURL?.lastPathComponent ?? "custom" }

    init(provider: SegmentationProvider = .apple, customModelURL: URL? = nil, customModelName: String? = nil,
         maskProfiles: [String: CustomMaskSettings] = [:]) {
        self.provider = provider
        self.customModelURL = customModelURL
        self.customModelName = customModelName
        self.maskProfiles = maskProfiles
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        provider = try values.decode(SegmentationProvider.self, forKey: .provider)
        customModelURL = try values.decodeIfPresent(URL.self, forKey: .customModelURL)
        customModelName = try values.decodeIfPresent(String.self, forKey: .customModelName)
        maskProfiles = try values.decodeIfPresent([String: CustomMaskSettings].self, forKey: .maskProfiles) ?? [:]
    }

    private enum CodingKeys: String, CodingKey { case provider, customModelURL, customModelName, maskProfiles }
}
