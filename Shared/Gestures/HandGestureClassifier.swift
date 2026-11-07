import Foundation

enum HandGestureClassifier {
    static func classify(_ hands: [HandLandmarks]) -> GestureObservation? {
        guard !hands.isEmpty, hands.count <= 2 else { return nil }
        let poses = hands.compactMap(HandPoseGeometry.init)
        guard poses.count == hands.count else { return nil }
        if poses.count == 2 {
            let a = poses[0], b = poses[1]
            let anchor = CGPoint(x: (a.anchor.x + b.anchor.x) / 2, y: (a.anchor.y + b.anchor.y) / 2)
            if isHeart(a, b) { return GestureObservation(gesture: .heartHands, anchor: anchor) }
            let pair: GestureKind? = switch (single(a), single(b)) {
            case (.openPalm, .openPalm): .doubleOpenPalm
            case (.thumbsUp, .thumbsUp): .doubleThumbsUp
            case (.thumbsDown, .thumbsDown): .doubleThumbsDown
            case (.peace, .peace): .doublePeace
            default: nil
            }
            // Mixed or uncertain pairs never fall back to a single-hand reaction.
            return pair.map { GestureObservation(gesture: $0, anchor: anchor) }
        }
        guard let pose = poses.first, let gesture = single(pose) else { return nil }
        let anchor = gesture == .fingerHeart
            ? pose.hand.points[.thumbTip] ?? pose.anchor : pose.anchor
        return GestureObservation(gesture: gesture, anchor: anchor)
    }

    private static func single(_ p: HandPoseGeometry) -> GestureKind? {
        if isFingerHeart(p) { return .fingerHeart }
        if p.allExtended && p.thumbExtended { return .openPalm }
        if p.state(.index) == .extended, p.state(.middle) == .extended,
           p.state(.ring) == .folded, p.state(.little) == .folded,
           p.thumbTucked, p.distance(.indexTip, .middleTip) > 0.4 { return .peace }
        if p.allFolded {
            if p.thumbExtended {
                if p.pointsVertically(from: .thumbMP, to: .thumbTip, upwards: true) { return .thumbsUp }
                if p.pointsVertically(from: .thumbMP, to: .thumbTip, upwards: false) { return .thumbsDown }
            }
            if p.thumbTucked { return .closedFist }
        }
        if p.state(.index) == .extended, p.state(.middle) == .folded,
           p.state(.ring) == .folded, p.state(.little) == .folded, p.thumbTucked,
           p.pointsVertically(from: .indexMCP, to: .indexTip, upwards: true) { return .pointingUp }
        return nil
    }

    private static func isFingerHeart(_ p: HandPoseGeometry) -> Bool {
        guard p.state(.middle) == .folded, p.state(.ring) == .folded, p.state(.little) == .folded,
              p.state(.index) != .extended, p.height(.thumbTip) > 1.1,
              p.distance(.thumbTip, .indexTip) > 0.1, p.distance(.thumbTip, .indexTip) < 0.55,
              p.height(.thumbTip) > p.height(.thumbIP) + 0.12,
              p.height(.indexTip) < p.height(.indexDIP) - 0.08 else { return false }
        // Require crossed distal segments. Merely touching fingertips (a pinch) is insufficient.
        return segmentsCross(p.point(.thumbIP), p.point(.thumbTip), p.point(.indexDIP), p.point(.indexTip))
    }

    private static func segmentsCross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let r = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let s = CGPoint(x: d.x - c.x, y: d.y - c.y)
        func cross(_ u: CGPoint, _ v: CGPoint) -> CGFloat { u.x * v.y - u.y * v.x }
        let denominator = cross(r, s)
        let lengths = hypot(r.x, r.y) * hypot(s.x, s.y)
        guard lengths > 0, abs(denominator) / lengths > 0.35 else { return false }
        let delta = CGPoint(x: c.x - a.x, y: c.y - a.y)
        let t = cross(delta, s) / denominator, u = cross(delta, r) / denominator
        return (0.08...0.92).contains(t) && (0.08...0.92).contains(u)
    }

    private static func isHeart(_ a: HandPoseGeometry, _ b: HandPoseGeometry) -> Bool {
        guard abs(a.hand.aspectRatio - b.hand.aspectRatio) < 0.001 else { return false }
        let scale = (a.scale + b.scale) / 2
        guard max(a.scale, b.scale) / min(a.scale, b.scale) < 1.8,
              HandPoseGeometry.distance(a.point(.indexTip), b.point(.indexTip)) < scale * 0.45,
              HandPoseGeometry.distance(a.point(.thumbTip), b.point(.thumbTip)) < scale * 0.45,
              a.distance(.indexTip, .thumbTip) > 0.7, b.distance(.indexTip, .thumbTip) > 0.7,
              !a.allExtended, !b.allExtended else { return false }
        let upper = CGPoint(x: (a.point(.indexTip).x + b.point(.indexTip).x) / 2,
                            y: (a.point(.indexTip).y + b.point(.indexTip).y) / 2)
        let lower = CGPoint(x: (a.point(.thumbTip).x + b.point(.thumbTip).x) / 2,
                            y: (a.point(.thumbTip).y + b.point(.thumbTip).y) / 2)
        guard upper.y - lower.y > scale * 0.5, abs(upper.x - lower.x) < scale * 0.6 else { return false }
        let left = a.point(.wrist).x < b.point(.wrist).x ? a : b
        let right = a.point(.wrist).x < b.point(.wrist).x ? b : a
        // The curled index fingers must form two distinct outer lobes around the contact point.
        return left.point(.indexPIP).x < upper.x - scale * 0.3
            && right.point(.indexPIP).x > upper.x + scale * 0.3
            && left.point(.wrist).x < lower.x - scale * 0.3
            && right.point(.wrist).x > lower.x + scale * 0.3
    }
}
