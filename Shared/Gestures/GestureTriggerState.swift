import Foundation

struct GestureObservation: Equatable, Sendable {
    let gesture: GestureKind
    /// Image coordinates, normalized to 0...1 with the origin at the bottom left.
    let anchor: CGPoint
}

struct GestureTriggerState: Sendable {
    private let holdDuration = 0.6
    private let maximumGap = 0.25
    private let maximumDrift: CGFloat = 0.16
    private var candidate: GestureObservation?
    private var startedAt: Double?
    private var lastSeenAt: Double?
    private var lastUpdateAt: Double?
    private var fired = false
    private var replacement: GestureObservation?
    private var replacementStartedAt: Double?

    mutating func reset() {
        candidate = nil
        startedAt = nil
        lastSeenAt = nil
        lastUpdateAt = nil
        fired = false
        replacement = nil
        replacementStartedAt = nil
    }

    mutating func update(observation: GestureObservation?, at time: Double) -> GestureObservation? {
        guard time.isFinite else { reset(); return nil }
        if let lastUpdateAt, time < lastUpdateAt { reset() }
        if let lastSeenAt, time - lastSeenAt > maximumGap { reset() }
        lastUpdateAt = time
        guard let observation, observation.anchor.x.isFinite, observation.anchor.y.isFinite,
              (0...1).contains(observation.anchor.x), (0...1).contains(observation.anchor.y) else { return nil }
        lastSeenAt = time
        if fired {
            // A stable different pose releases the old gesture; brief misclassifications do not.
            if candidate?.gesture == observation.gesture {
                replacement = nil
                replacementStartedAt = nil
                return nil
            }
            guard let replacement, let replacementStartedAt,
                  replacement.gesture == observation.gesture,
                  hypot(replacement.anchor.x - observation.anchor.x, replacement.anchor.y - observation.anchor.y) <= maximumDrift else {
                self.replacement = observation
                self.replacementStartedAt = time
                return nil
            }
            guard time - replacementStartedAt >= maximumGap else { return nil }
            fired = false
            candidate = replacement
            startedAt = replacementStartedAt
            self.replacement = nil
            self.replacementStartedAt = nil
        }
        if let candidate,
           candidate.gesture == observation.gesture,
           hypot(candidate.anchor.x - observation.anchor.x, candidate.anchor.y - observation.anchor.y) <= maximumDrift {
            if let startedAt, time - startedAt + 0.000001 >= holdDuration {
                fired = true
                return observation
            }
        } else {
            candidate = observation
            startedAt = time
        }
        return nil
    }
}
