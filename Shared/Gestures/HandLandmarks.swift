import Foundation

enum HandJoint: CaseIterable, Hashable, Sendable {
    case wrist, thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

struct HandLandmarks: Sendable {
    let points: [HandJoint: CGPoint]
    /// Corrects normalized image coordinates before measuring angles and distances.
    var aspectRatio: CGFloat = 1
}

struct HandPoseGeometry {
    enum Finger { case index, middle, ring, little }
    enum FingerState { case extended, folded, uncertain }

    let hand: HandLandmarks
    let scale: CGFloat
    private let points: [HandJoint: CGPoint]
    private let forward: CGPoint

    init?(_ hand: HandLandmarks) {
        guard hand.aspectRatio.isFinite, hand.aspectRatio > 0,
              HandJoint.allCases.allSatisfy({ joint in
                  guard let p = hand.points[joint] else { return false }
                  return p.x.isFinite && p.y.isFinite && (0...1).contains(p.x) && (0...1).contains(p.y)
              }) else { return nil }
        self.hand = hand
        points = hand.points.mapValues { CGPoint(x: $0.x * hand.aspectRatio, y: $0.y) }
        let wrist = points[.wrist] ?? .zero
        let middle = points[.middleMCP] ?? .zero
        scale = Self.distance(wrist, middle)
        guard scale > 0.01 else { return nil }
        forward = CGPoint(x: (middle.x - wrist.x) / scale, y: (middle.y - wrist.y) / scale)
        let palmWidth = Self.distance(points[.indexMCP] ?? .zero, points[.littleMCP] ?? .zero)
        guard palmWidth / scale > 0.35, palmWidth / scale < 1.8 else { return nil }
    }

    func point(_ joint: HandJoint) -> CGPoint { points[joint] ?? .zero }
    var anchor: CGPoint { hand.points[.middleMCP] ?? .zero }
    func distance(_ a: HandJoint, _ b: HandJoint) -> CGFloat { Self.distance(point(a), point(b)) / scale }
    func height(_ joint: HandJoint) -> CGFloat {
        let p = point(joint), wrist = point(.wrist)
        return ((p.x - wrist.x) * forward.x + (p.y - wrist.y) * forward.y) / scale
    }

    func state(_ finger: Finger) -> FingerState {
        let joints: [HandJoint] = switch finger {
        case .index: [.indexMCP, .indexPIP, .indexDIP, .indexTip]
        case .middle: [.middleMCP, .middlePIP, .middleDIP, .middleTip]
        case .ring: [.ringMCP, .ringPIP, .ringDIP, .ringTip]
        case .little: [.littleMCP, .littlePIP, .littleDIP, .littleTip]
        }
        let p = joints.map(point)
        let segments = (0..<3).map { Self.distance(p[$0], p[$0 + 1]) }
        guard segments.allSatisfy({ $0 > scale * 0.06 }) else { return .uncertain }
        let length = segments.reduce(0, +)
        guard length > scale * 0.4 else { return .uncertain }
        let straightness = Self.distance(p[0], p[3]) / length
        if straightness > 0.88, height(joints[3]) - height(joints[0]) > 0.6,
           distance(joints[3], .wrist) - distance(joints[1], .wrist) > 0.18 { return .extended }
        if straightness < 0.84, height(joints[3]) < height(joints[0]) + 0.32,
           distance(joints[3], .wrist) < distance(joints[1], .wrist) - 0.05 { return .folded }
        return .uncertain
    }

    var thumbExtended: Bool {
        let length = distance(.thumbCMC, .thumbMP) + distance(.thumbMP, .thumbIP) + distance(.thumbIP, .thumbTip)
        return length > 0.5 && distance(.thumbCMC, .thumbTip) / length > 0.8
            && distance(.thumbTip, .indexMCP) > 0.6 && distance(.thumbCMC, .thumbTip) > 0.75
    }

    var thumbTucked: Bool { !thumbExtended && distance(.thumbTip, .indexMCP) < 0.65 }
    var allFolded: Bool { [.index, .middle, .ring, .little].allSatisfy { state($0) == .folded } }
    var allExtended: Bool { [.index, .middle, .ring, .little].allSatisfy { state($0) == .extended } }

    func pointsVertically(from start: HandJoint, to end: HandJoint, upwards: Bool) -> Bool {
        let a = point(start), b = point(end)
        let length = Self.distance(a, b)
        return length > scale * 0.4 && (b.y - a.y) * (upwards ? 1 : -1) / length > 0.72
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
