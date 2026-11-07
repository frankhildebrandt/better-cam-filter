import CoreImage

/// Bridges asynchronous gesture observations into the synchronous video compositor.
final class GestureReactionProcessor {
    private let worker = GestureAnalysisWorker()
    private lazy var renderer = ReactionRenderer()
    private var playback = GestureReactionPlayback()
    private var lastObservationTime = -Double.infinity
    private(set) var detectedGesture: GestureKind?
    private(set) var error: String?

    var configuration = GestureConfiguration() {
        didSet {
            guard configuration != oldValue else { return }
            playback.configuration = configuration
            reset()
        }
    }

    func reset() {
        worker.reset()
        playback.reset()
        detectedGesture = nil
        error = nil
        lastObservationTime = -Double.infinity
    }

    func preview(_ reaction: ReactionKind, for gesture: GestureKind, at time: Double) {
        playback.preview(reaction, for: gesture, at: time)
    }

    func frame(for image: CIImage, at time: Double) -> ReactionLayers {
        if configuration.enabled {
            worker.submit(image, at: time)
            if let result = worker.snapshot(at: time) {
                detectedGesture = result.observation?.gesture
                error = result.error
                if result.time > lastObservationTime {
                    playback.observe(result.observation, at: result.time)
                    lastObservationTime = result.time
                }
            } else {
                detectedGesture = nil
                playback.observe(nil, at: time)
            }
        }
        playback.expire(at: time)
        guard let active = playback.active else { return ReactionLayers(foreground: nil, background: nil) }
        return renderer.frame(reaction: active.reaction, progress: active.progress(at: time),
                              anchor: active.anchor, bounds: image.extent)
    }
}
