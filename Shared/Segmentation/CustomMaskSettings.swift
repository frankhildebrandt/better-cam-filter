import Foundation

struct CustomMaskSettings: Codable, Equatable, Sendable {
    var enabled: Bool
    var threshold: Double
    var transition: Double
    var edgeInset: Double
    var temporalStrength: Double
    var personSupport: Bool

    static let balanced = Self()
    static let original = Self(enabled: false, edgeInset: 0, temporalStrength: 0)
    static let detailed = Self(threshold: 0.35, transition: 0.12, edgeInset: 0.5)
    static let cleanEdges = Self(threshold: 0.55, transition: 0.12, edgeInset: 2)

    init(enabled: Bool = true, threshold: Double = 0.45, transition: Double = 0.16,
         edgeInset: Double = 1, temporalStrength: Double = 0.5, personSupport: Bool = false) {
        self.enabled = enabled
        self.threshold = Self.clamp(threshold, to: 0.05...0.95, fallback: 0.45)
        self.transition = Self.clamp(transition, to: 0.02...1, fallback: 0.16)
        self.edgeInset = Self.clamp(edgeInset, to: -4...6, fallback: 1)
        self.temporalStrength = Self.clamp(temporalStrength, to: 0...1, fallback: 0.5)
        self.personSupport = personSupport
    }

    /// Validate again after direct mutations or decoding old settings documents.
    var sanitized: Self {
        Self(enabled: enabled, threshold: threshold, transition: transition, edgeInset: edgeInset,
             temporalStrength: temporalStrength, personSupport: personSupport)
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true,
                  threshold: try values.decodeIfPresent(Double.self, forKey: .threshold) ?? 0.45,
                  transition: try values.decodeIfPresent(Double.self, forKey: .transition) ?? 0.16,
                  edgeInset: try values.decodeIfPresent(Double.self, forKey: .edgeInset) ?? 1,
                  temporalStrength: try values.decodeIfPresent(Double.self, forKey: .temporalStrength) ?? 0.5,
                  personSupport: try values.decodeIfPresent(Bool.self, forKey: .personSupport) ?? false)
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, threshold, transition, edgeInset, temporalStrength, personSupport
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}
