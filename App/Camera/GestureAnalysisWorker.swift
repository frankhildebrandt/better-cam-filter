import CoreImage
import Foundation

struct GestureAnalysisResult {
    let observation: GestureObservation?
    let time: Double
    let error: String?
}

/// Bounds Vision work to one retained camera frame; all detector access stays on its worker queue.
final class GestureAnalysisWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.bettercam.gestures", qos: .utility)
    private let detector = HandGestureDetector()
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var busy = false
    private var nextAnalysis = 0.0
    private var latest: GestureAnalysisResult?

    func reset() {
        lock.lock()
        generation &+= 1
        nextAnalysis = 0
        latest = nil
        lock.unlock()
    }

    func snapshot(at time: Double) -> GestureAnalysisResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let latest, time >= latest.time, time - latest.time < 0.5 else { return nil }
        return latest
    }

    func submit(_ image: CIImage, at time: Double) {
        lock.lock()
        guard !busy, time >= nextAnalysis else { lock.unlock(); return }
        busy = true
        nextAnalysis = time + 0.1
        let token = generation
        lock.unlock()

        // CIImage is immutable and retains this one input buffer until analysis finishes.
        let input = Input(image: image, time: time, generation: token)
        queue.async { [self, input] in
            let result: GestureAnalysisResult = autoreleasepool {
                do {
                    let scale = min(1, 640 / input.image.extent.width)
                    let small = input.image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    return GestureAnalysisResult(observation: try detector.detect(in: small), time: input.time, error: nil)
                } catch {
                    return GestureAnalysisResult(observation: nil, time: input.time,
                                                 error: "Gestenerkennung fehlgeschlagen: \(error.localizedDescription)")
                }
            }
            lock.lock()
            if generation == input.generation { latest = result }
            busy = false
            lock.unlock()
        }
    }

    private struct Input: @unchecked Sendable {
        let image: CIImage
        let time: Double
        let generation: UInt64
    }
}
