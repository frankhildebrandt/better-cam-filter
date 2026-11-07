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
    var appleSettings = AppleRecognitionSettings()
    var inferenceProfiles: [String: ModelInferenceSettings] = [:]
    var hasMaskSettings: Bool { maskProfiles[profileKey] != nil }

    var maskSettings: CustomMaskSettings {
        get { (maskProfiles[profileKey] ?? (provider == .apple ? .original : .balanced)).sanitized }
        set { maskProfiles[profileKey] = newValue.sanitized }
    }

    var inferenceSettings: ModelInferenceSettings {
        get { inferenceProfiles[profileKey] ?? ModelInferenceSettings() }
        set { inferenceProfiles[profileKey] = newValue }
    }

    private var profileKey: String { provider == .apple ? "apple" : customModelURL?.lastPathComponent ?? "custom" }

    init(provider: SegmentationProvider = .apple, customModelURL: URL? = nil, customModelName: String? = nil,
         maskProfiles: [String: CustomMaskSettings] = [:], appleSettings: AppleRecognitionSettings = .init(),
         inferenceProfiles: [String: ModelInferenceSettings] = [:]) {
        self.provider = provider
        self.customModelURL = customModelURL
        self.customModelName = customModelName
        self.maskProfiles = maskProfiles
        self.appleSettings = appleSettings.sanitized
        self.inferenceProfiles = inferenceProfiles
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        provider = try values.decode(SegmentationProvider.self, forKey: .provider)
        customModelURL = try values.decodeIfPresent(URL.self, forKey: .customModelURL)
        customModelName = try values.decodeIfPresent(String.self, forKey: .customModelName)
        maskProfiles = try values.decodeIfPresent([String: CustomMaskSettings].self, forKey: .maskProfiles) ?? [:]
        appleSettings = try values.decodeIfPresent(AppleRecognitionSettings.self, forKey: .appleSettings)?.sanitized ?? .init()
        inferenceProfiles = try values.decodeIfPresent([String: ModelInferenceSettings].self, forKey: .inferenceProfiles) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case provider, customModelURL, customModelName, maskProfiles, appleSettings, inferenceProfiles
    }
}

enum RecognitionQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case fast, balanced, accurate
    var id: Self { self }
    var title: String {
        switch self {
        case .fast: "Schnell"
        case .balanced: "Ausgewogen"
        case .accurate: "Präzise"
        }
    }
}

struct AppleRecognitionSettings: Codable, Equatable, Sendable {
    var quality: RecognitionQuality = .accurate
    /// Zero uses the complete output image; other values cap the analysis width.
    var analysisWidth = 768
    /// Zero follows the system's default revision.
    var revision = 0
    var preferBackgroundProcessing = false

    init(quality: RecognitionQuality = .accurate, analysisWidth: Int = 768, revision: Int = 0,
         preferBackgroundProcessing: Bool = false) {
        self.quality = quality
        self.analysisWidth = analysisWidth
        self.revision = revision
        self.preferBackgroundProcessing = preferBackgroundProcessing
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(quality: try values.decodeIfPresent(RecognitionQuality.self, forKey: .quality) ?? .accurate,
                  analysisWidth: try values.decodeIfPresent(Int.self, forKey: .analysisWidth) ?? 768,
                  revision: try values.decodeIfPresent(Int.self, forKey: .revision) ?? 0,
                  preferBackgroundProcessing: try values.decodeIfPresent(Bool.self, forKey: .preferBackgroundProcessing) ?? false)
        self = sanitized
    }

    private enum CodingKeys: String, CodingKey { case quality, analysisWidth, revision, preferBackgroundProcessing }

    var sanitized: Self {
        var result = self
        result.analysisWidth = analysisWidth == 0 ? 0 : min(3840, max(128, analysisWidth))
        result.revision = max(0, revision)
        return result
    }
}

enum ModelComputeUnits: String, Codable, CaseIterable, Identifiable, Sendable {
    case all, cpuOnly, cpuAndGPU, cpuAndNeuralEngine
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "Automatisch (alle)"
        case .cpuOnly: "Nur CPU"
        case .cpuAndGPU: "CPU und GPU"
        case .cpuAndNeuralEngine: "CPU und Neural Engine"
        }
    }
}

enum ModelInputScaling: String, Codable, CaseIterable, Identifiable, Sendable {
    case stretch, aspectFit, aspectFill
    var id: Self { self }
    var title: String {
        switch self {
        case .stretch: "Auf Modellgröße strecken"
        case .aspectFit: "Vollständiges Bild einpassen"
        case .aspectFill: "Modellgröße ausfüllen"
        }
    }
}

struct ModelInferenceSettings: Codable, Equatable, Sendable {
    var computeUnits: ModelComputeUnits = .all
    var inputScaling: ModelInputScaling = .stretch

    init(computeUnits: ModelComputeUnits = .all, inputScaling: ModelInputScaling = .stretch) {
        self.computeUnits = computeUnits
        self.inputScaling = inputScaling
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(computeUnits: try values.decodeIfPresent(ModelComputeUnits.self, forKey: .computeUnits) ?? .all,
                  inputScaling: try values.decodeIfPresent(ModelInputScaling.self, forKey: .inputScaling) ?? .stretch)
    }

    private enum CodingKeys: String, CodingKey { case computeUnits, inputScaling }
}
