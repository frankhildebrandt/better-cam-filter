import CoreGraphics

struct ActiveGestureReaction {
    let reaction: ReactionKind
    let anchor: CGPoint
    let startedAt: Double

    func progress(at time: Double) -> Double { (time - startedAt) / reaction.duration }
}

/// Owns hold/release gating and a single animation on the capture queue.
struct GestureReactionPlayback {
    var configuration = GestureConfiguration() {
        didSet { if configuration != oldValue { reset() } }
    }
    private var trigger = GestureTriggerState()
    private(set) var active: ActiveGestureReaction?

    mutating func observe(_ observation: GestureObservation?, at time: Double) {
        if let active, time >= active.startedAt { expire(at: time) }
        guard configuration.enabled else { return }
        let assigned = observation.flatMap { configuration.reaction(for: $0.gesture) == nil ? nil : $0 }
        guard let event = trigger.update(observation: assigned, at: time),
              let reaction = configuration.reaction(for: event.gesture), active == nil else { return }
        active = ActiveGestureReaction(reaction: reaction, anchor: event.anchor, startedAt: time)
    }

    /// A settings preview can run even when automatic gesture recognition is disabled.
    mutating func preview(_ reaction: ReactionKind, for gesture: GestureKind, at time: Double) {
        guard reaction.compatibleGestures.contains(gesture) else { return }
        active = ActiveGestureReaction(reaction: reaction, anchor: CGPoint(x: 0.65, y: 0.42), startedAt: time)
    }

    mutating func expire(at time: Double) {
        guard let active else { return }
        if time < active.startedAt || active.progress(at: time) >= 1 { self.active = nil }
    }

    mutating func reset() {
        trigger.reset()
        active = nil
    }
}
