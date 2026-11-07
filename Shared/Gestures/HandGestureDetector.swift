import CoreImage
import Vision

/// Confine an instance and its Vision request to one serial analysis worker.
final class HandGestureDetector {
    private var request = HandGestureDetector.makeRequest()
    private let minimumConfidence: Float = 0.35

    func reset() { request = Self.makeRequest() }

    func detect(in image: CIImage) throws -> GestureObservation? {
        let bounds = image.extent
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { return nil }
        let factor = min(1, 640 / max(bounds.width, bounds.height))
        let analysis = image.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        try VNImageRequestHandler(ciImage: analysis, orientation: .up).perform([request])
        let observations = request.results ?? []
        var hands: [HandLandmarks] = []
        for observation in observations {
            let recognized = try observation.recognizedPoints(.all)
            var points: [HandJoint: CGPoint] = [:]
            for (joint, visionJoint) in Self.joints {
                guard let point = recognized[visionJoint], point.confidence >= minimumConfidence else { return nil }
                points[joint] = point.location
            }
            hands.append(HandLandmarks(points: points, aspectRatio: bounds.width / bounds.height))
        }
        return HandGestureClassifier.classify(hands)
    }

    private static func makeRequest() -> VNDetectHumanHandPoseRequest {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }

    private static let joints: [(HandJoint, VNHumanHandPoseObservation.JointName)] = [
        (.wrist, .wrist), (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
        (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
        (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
        (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
        (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip)
    ]
}
