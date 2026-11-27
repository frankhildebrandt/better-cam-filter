import CoreImage
import CoreMedia
import Foundation

/// One camera frame with its raw segmentation, handed from the analysis queue to the composition queue.
/// Nothing in it is mutated after the hand-over.
struct AnalyzedFrame: @unchecked Sendable {
    let input: CVPixelBuffer
    let time: CMTime
    /// The camera image aspect-filled to the output bounds.
    let foreground: CIImage
    /// Nil when no stage needed a mask for this frame.
    let segmentation: Result<SegmentationAnalysis, any Error>?
}

/// Throttles camera frames to the output rate and runs Vision or Core ML on them.
/// CaptureEngine confines it to its analysis queue, so the next frame's analysis overlaps composition.
final class FrameAnalysisStage {
    var outputConfiguration = OutputConfiguration() {
        didSet { if outputConfiguration != oldValue { reset() } }
    }
    var segmentationConfiguration: SegmentationConfiguration {
        get { analyzer.configuration }
        set { if newValue != analyzer.configuration { analyzer.configuration = newValue } }
    }
    /// A replacement background needs a mask for every frame.
    var backgroundEnabled = false {
        didSet { if backgroundEnabled != oldValue { analyzer.reset() } }
    }
    /// Rear gesture reactions need a person mask while they play.
    var reactionsNeedMask = false
    private let analyzer = SegmentationAnalyzer()
    private var nextFrame: TimeInterval = 0
    private var inputSize = CGSize.zero

    func reset() {
        analyzer.reset()
        nextFrame = 0
        inputSize = .zero
    }

    /// Accept frames at the configured output rate; cameras may deliver faster.
    func admit(at now: TimeInterval) -> Bool {
        guard now + 0.001 >= nextFrame else { return false }
        let interval = 1.0 / Double(outputConfiguration.frameRate)
        nextFrame = nextFrame == 0 ? now + interval : max(nextFrame + interval, now)
        return true
    }

    /// Crop the frame to the output and segment it when a mask is needed. Failures restart Vision's sequence.
    func analyze(_ input: CVPixelBuffer, at time: CMTime) -> AnalyzedFrame {
        let size = CGSize(width: CVPixelBufferGetWidth(input), height: CVPixelBufferGetHeight(input))
        if size != inputSize {
            analyzer.reset()
            inputSize = size
        }
        let foreground = FrameComposition.aspectFill(CIImage(cvPixelBuffer: input), in: outputConfiguration.bounds)
        let segmentation = backgroundEnabled || reactionsNeedMask ? Result { try analyzer.analyze(foreground) } : nil
        if case .failure = segmentation { analyzer.reset() }
        return AnalyzedFrame(input: input, time: time, foreground: foreground, segmentation: segmentation)
    }
}
