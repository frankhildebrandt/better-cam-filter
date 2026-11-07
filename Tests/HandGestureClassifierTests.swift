import Foundation
import Testing
@testable import BetterCamCore

struct HandGestureClassifierTests {
    @Test func recognizesDistinctSingleHandPoses() {
        for gesture in [GestureKind.peace, .thumbsUp, .thumbsDown, .openPalm, .closedFist, .pointingUp, .fingerHeart] {
            #expect(HandGestureClassifier.classify([fixture(gesture)])?.gesture == gesture)
        }
    }

    @Test func poseRulesHandleMirroringRotationScaleAndNonSquareImages() {
        for angle in [-1.1, 0, 0.8] {
            for scale in [0.08, 0.13] {
                for aspect in [1.0, 16.0 / 9.0] {
                    for mirror in [-1.0, 1.0] {
                        let hand = fixture(.peace, angle: angle, scale: scale, aspect: aspect, mirror: mirror)
                        #expect(HandGestureClassifier.classify([hand])?.gesture == .peace)
                    }
                }
            }
        }
        #expect(HandGestureClassifier.classify([fixture(.thumbsUp, angle: .pi / 2)]) == nil)
    }

    @Test func twoHandPosesTakePrecedenceAndHaveACentralAnchor() {
        let pairs: [(GestureKind, GestureKind)] = [
            (.peace, .doublePeace), (.openPalm, .doubleOpenPalm),
            (.thumbsUp, .doubleThumbsUp), (.thumbsDown, .doubleThumbsDown)
        ]
        for (single, double) in pairs {
            let hands = [fixture(single, center: CGPoint(x: 0.3, y: 0.3)),
                         fixture(single, center: CGPoint(x: 0.7, y: 0.3))]
            let result = HandGestureClassifier.classify(hands)
            #expect(result?.gesture == double)
            #expect(abs((result?.anchor.x ?? 0) - 0.5) < 0.001)
        }
    }

    @Test func mixedUncertainOrIncompletePairsNeverFallBackToOneHand() {
        let peace = fixture(.peace)
        #expect(HandGestureClassifier.classify([peace, fixture(.thumbsUp)]) == nil)
        var incomplete = fixture(.openPalm).points
        incomplete.removeValue(forKey: .littleDIP)
        #expect(HandGestureClassifier.classify([peace, HandLandmarks(points: incomplete)]) == nil)
        #expect(HandGestureClassifier.classify([peace, fixture(.pointingUp)]) == nil)
        #expect(HandGestureClassifier.classify([peace, peace, peace]) == nil)
    }

    @Test func heartRequiresBothUpperAndLowerContactsAndTwoOuterLobes() {
        let hands = heart()
        #expect(HandGestureClassifier.classify(hands)?.gesture == .heartHands)
        var broken = hands[1].points
        broken[.thumbTip] = CGPoint(x: 0.7, y: 0.25)
        #expect(HandGestureClassifier.classify([hands[0], HandLandmarks(points: broken)]) == nil)
        #expect(HandGestureClassifier.classify([fixture(.openPalm), fixture(.openPalm)])?.gesture != .heartHands)
    }

    @Test func genericPinchesAndUncrossedFingersAreNotFingerHearts() {
        var pinch = fixture(.fingerHeart).points
        let contact = CGPoint(x: 0.49, y: 0.486)
        pinch[.thumbTip] = contact
        pinch[.indexTip] = contact
        #expect(HandGestureClassifier.classify([HandLandmarks(points: pinch)])?.gesture != .fingerHeart)
        var uncrossed = fixture(.fingerHeart).points
        uncrossed[.thumbTip] = CGPoint(x: 0.40, y: 0.49)
        #expect(HandGestureClassifier.classify([HandLandmarks(points: uncrossed)])?.gesture != .fingerHeart)
    }

    @Test func uncertainFingersInvalidPointsAndCollapsedPalmsAreRejected() {
        var bent = fixture(.peace).points
        bent[.indexTip] = bent[.indexDIP]
        #expect(HandGestureClassifier.classify([HandLandmarks(points: bent)])?.gesture != .peace)
        var invalid = fixture(.openPalm).points
        invalid[.wrist] = CGPoint(x: CGFloat.nan, y: 0.2)
        #expect(HandGestureClassifier.classify([HandLandmarks(points: invalid)]) == nil)
        let collapsed = Dictionary(uniqueKeysWithValues: HandJoint.allCases.map { ($0, CGPoint(x: 0.5, y: 0.5)) })
        #expect(HandGestureClassifier.classify([HandLandmarks(points: collapsed)]) == nil)
        #expect(HandGestureClassifier.classify([]) == nil)
    }

    private func fixture(_ gesture: GestureKind, angle: Double = 0, scale: Double = 0.12,
                         aspect: Double = 1, mirror: Double = 1,
                         center: CGPoint = CGPoint(x: 0.5, y: 0.3)) -> HandLandmarks {
        var points = base()
        if [.peace, .openPalm, .pointingUp].contains(gesture) { extend(.index, points: &points) }
        if [.peace, .openPalm].contains(gesture) { extend(.middle, points: &points) }
        if gesture == .openPalm {
            extend(.ring, points: &points)
            extend(.little, points: &points)
            points[.thumbMP] = CGPoint(x: -0.65, y: 0.55)
            points[.thumbIP] = CGPoint(x: -1, y: 0.75)
            points[.thumbTip] = CGPoint(x: -1.35, y: 0.9)
        }
        if [.thumbsUp, .thumbsDown].contains(gesture) {
            points[.thumbCMC] = CGPoint(x: -0.6, y: 0.4)
            points[.thumbMP] = CGPoint(x: -0.85, y: 0.85)
            points[.thumbIP] = CGPoint(x: -0.9, y: 1.4)
            points[.thumbTip] = CGPoint(x: -0.9, y: 2)
        }
        if gesture == .fingerHeart {
            points[.indexPIP] = CGPoint(x: -0.65, y: 1.65)
            points[.indexDIP] = CGPoint(x: -0.45, y: 1.7)
            points[.indexTip] = CGPoint(x: -0.15, y: 1.25)
            points[.thumbIP] = CGPoint(x: -0.55, y: 1.05)
            points[.thumbTip] = CGPoint(x: -0.05, y: 1.65)
        }
        return transform(points, angle: gesture == .thumbsDown ? angle + .pi : angle,
                         scale: scale, aspect: aspect, mirror: mirror, center: center)
    }

    private func base() -> [HandJoint: CGPoint] {
        var points: [HandJoint: CGPoint] = [
            .wrist: .zero, .thumbCMC: CGPoint(x: -0.3, y: 0.3), .thumbMP: CGPoint(x: -0.65, y: 0.6),
            .thumbIP: CGPoint(x: -0.55, y: 0.95), .thumbTip: CGPoint(x: -0.2, y: 1.1),
            .indexMCP: CGPoint(x: -0.4, y: 0.95), .middleMCP: CGPoint(x: 0, y: 1),
            .ringMCP: CGPoint(x: 0.34, y: 0.92), .littleMCP: CGPoint(x: 0.65, y: 0.8)
        ]
        for joints: [HandJoint] in [[.indexMCP, .indexPIP, .indexDIP, .indexTip],
                                    [.middleMCP, .middlePIP, .middleDIP, .middleTip],
                                    [.ringMCP, .ringPIP, .ringDIP, .ringTip],
                                    [.littleMCP, .littlePIP, .littleDIP, .littleTip]] {
            let origin = points[joints[0]] ?? .zero
            points[joints[1]] = CGPoint(x: origin.x, y: origin.y + 0.45)
            points[joints[2]] = CGPoint(x: origin.x + 0.1, y: origin.y + 0.22)
            points[joints[3]] = CGPoint(x: origin.x + 0.02, y: origin.y - 0.2)
        }
        return points
    }

    private func extend(_ finger: HandPoseGeometry.Finger, points: inout [HandJoint: CGPoint]) {
        let joints: [HandJoint], tip: CGPoint
        switch finger {
        case .index: joints = [.indexMCP, .indexPIP, .indexDIP, .indexTip]; tip = CGPoint(x: -0.75, y: 2.4)
        case .middle: joints = [.middleMCP, .middlePIP, .middleDIP, .middleTip]; tip = CGPoint(x: 0.1, y: 2.7)
        case .ring: joints = [.ringMCP, .ringPIP, .ringDIP, .ringTip]; tip = CGPoint(x: 0.45, y: 2.4)
        case .little: joints = [.littleMCP, .littlePIP, .littleDIP, .littleTip]; tip = CGPoint(x: 0.9, y: 2)
        }
        let origin = points[joints[0]] ?? .zero
        for index in 1...3 {
            let fraction = CGFloat(index) / 3
            points[joints[index]] = CGPoint(x: origin.x + (tip.x - origin.x) * fraction,
                                           y: origin.y + (tip.y - origin.y) * fraction)
        }
    }

    private func heart() -> [HandLandmarks] {
        var left = base().mapValues { CGPoint(x: $0.x - 1, y: $0.y) }
        left[.indexPIP] = CGPoint(x: -0.7, y: 2.1)
        left[.indexDIP] = CGPoint(x: -0.2, y: 2)
        left[.indexTip] = CGPoint(x: -0.05, y: 1.75)
        left[.thumbMP] = CGPoint(x: -0.9, y: 0.5)
        left[.thumbIP] = CGPoint(x: -0.5, y: 0.5)
        left[.thumbTip] = CGPoint(x: -0.05, y: 0.65)
        let right = left.mapValues { CGPoint(x: -$0.x, y: $0.y) }
        return [transform(left), transform(right)]
    }

    private func transform(_ points: [HandJoint: CGPoint], angle: Double = 0, scale: Double = 0.12,
                           aspect: Double = 1, mirror: Double = 1,
                           center: CGPoint = CGPoint(x: 0.5, y: 0.3)) -> HandLandmarks {
        let transformed = points.mapValues { p in
            let x = p.x * mirror
            return CGPoint(x: (x * cos(angle) - p.y * sin(angle)) * scale / aspect + center.x,
                           y: (x * sin(angle) + p.y * cos(angle)) * scale + center.y)
        }
        return HandLandmarks(points: transformed, aspectRatio: aspect)
    }
}
