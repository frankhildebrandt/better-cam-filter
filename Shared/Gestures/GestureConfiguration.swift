import Foundation

struct GestureConfiguration: Codable, Equatable, Sendable {
    var enabled = false
    private var assignments: [String: String] = [
        GestureKind.peace.rawValue: ReactionKind.bunnyPeek.rawValue,
        GestureKind.thumbsUp.rawValue: ReactionKind.goodBean.rawValue,
        GestureKind.openPalm.rawValue: ReactionKind.pawFive.rawValue,
        GestureKind.heartHands.rawValue: ReactionKind.lovePuff.rawValue,
        GestureKind.doubleOpenPalm.rawValue: ReactionKind.rainbowYay.rawValue,
        GestureKind.fingerHeart.rawValue: ReactionKind.tinyLove.rawValue
    ]

    init() {}

    func reaction(for gesture: GestureKind) -> ReactionKind? {
        guard let value = assignments[gesture.rawValue], let reaction = ReactionKind(rawValue: value),
              reaction.compatibleGestures.contains(gesture) else { return nil }
        return reaction
    }

    mutating func assign(_ reaction: ReactionKind?, to gesture: GestureKind) {
        guard let reaction else {
            assignments.removeValue(forKey: gesture.rawValue)
            return
        }
        guard reaction.compatibleGestures.contains(gesture) else { return }
        assignments[gesture.rawValue] = reaction.rawValue
    }

    private enum CodingKeys: String, CodingKey { case enabled, assignments }
    private struct AssignmentKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        guard container.contains(.assignments) else { return }
        assignments = [:]
        guard let values = try? container.nestedContainer(keyedBy: AssignmentKey.self, forKey: .assignments) else { return }
        for key in values.allKeys {
            guard let gesture = GestureKind(rawValue: key.stringValue),
                  let value = try? values.decode(String.self, forKey: key),
                  let reaction = ReactionKind(rawValue: value) else { continue }
            assign(reaction, to: gesture)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(assignments, forKey: .assignments)
    }
}
