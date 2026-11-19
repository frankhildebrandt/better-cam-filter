import CoreGraphics

/// Confirm object evidence even during semantic coverage; never use person alpha itself as evidence.
final class AccessoryTemporalFilter {
    private var firstSeen = [Double]()
    private var missingSince = [Double]()
    private var changedSince = [Double]()
    private var confirmed = [Bool]()
    private var observations = [UInt8]()
    private var misses = [UInt8]()
    private var colorMisses = [UInt8]()
    private var colors = [UInt8]()
    private var scene = AccessorySceneHistory()
    private var dimensions = (width: 0, height: 0)
    private var lastTime: Double?
    private var previousPersonBounds = CGRect.null

    func reset() {
        firstSeen = []
        missingSince = []
        changedSince = []
        confirmed = []
        observations = []
        misses = []
        colorMisses = []
        colors = []
        scene = AccessorySceneHistory()
        dimensions = (0, 0)
        lastTime = nil
        previousPersonBounds = .null
    }

    func filter(_ evidence: [UInt8], person: [UInt8], rgba: [UInt8],
                width: Int, height: Int, time: Double) -> [UInt8] {
        let count = evidence.count
        guard width > 0, height > 0, count == width * height, person.count == count,
              rgba.count == count * 4, time.isFinite else { reset(); return [UInt8](repeating: 0, count: count) }
        let discontinuity = lastTime.map { time < $0 || time - $0 > 0.3 } ?? false
        if dimensions != (width, height) || discontinuity {
            reset()
            firstSeen = [Double](repeating: -1, count: count)
            missingSince = [Double](repeating: -1, count: count)
            changedSince = [Double](repeating: -1, count: count)
            confirmed = [Bool](repeating: false, count: count)
            observations = [UInt8](repeating: 0, count: count)
            misses = [UInt8](repeating: 0, count: count)
            colorMisses = [UInt8](repeating: 0, count: count)
            colors = rgba
            dimensions = (width, height)
        }
        guard let bounds = Self.personBounds(person, width: width) else {
            reset()
            return [UInt8](repeating: 0, count: count)
        }
        let margin = CGFloat(max(2, width / 5))
        let relocated = !previousPersonBounds.isNull
            && !bounds.insetBy(dx: -margin, dy: -margin).intersects(previousPersonBounds)
        if scene.changed(rgba: rgba, person: person, evidence: evidence, confirmed: confirmed) || relocated {
            for pixel in evidence.indices { clear(pixel) }
        }
        previousPersonBounds = bounds
        lastTime = time
        let motion = AccessoryMotionSupport.transfer(evidence: evidence, confirmed: confirmed,
                                                     colors: colors, rgba: rgba, width: width, height: height)
        for pixel in motion.vacated { clear(pixel) }
        var output = [UInt8](repeating: 0, count: count)
        for pixel in evidence.indices {
            if evidence[pixel] > 200 {
                if !confirmed[pixel] && !motion.inherited[pixel] && colorDifference(pixel, rgba: rgba) > 40 { clear(pixel) }
                if firstSeen[pixel] < 0 {
                    firstSeen[pixel] = time
                    for channel in 0..<3 { colors[pixel * 4 + channel] = rgba[pixel * 4 + channel] }
                }
                missingSince[pixel] = -1
                changedSince[pixel] = -1
                misses[pixel] = 0
                colorMisses[pixel] = 0
                observations[pixel] = min(3, observations[pixel] + 1)
                if motion.inherited[pixel] || (observations[pixel] >= 3 && time - firstSeen[pixel] >= 0.10) {
                    confirmed[pixel] = true
                }
                if confirmed[pixel] { updateColor(pixel, rgba: rgba) }
            } else if confirmed[pixel] {
                let difference = colorDifference(pixel, rgba: rgba)
                // A confirmed mic may merge into a dark shirt. While Vision covers
                // the same appearance it can retain, but never create, confirmation.
                if person[pixel] > 200 && difference <= 24 {
                    missingSince[pixel] = -1
                    changedSince[pixel] = -1
                    misses[pixel] = 0
                    colorMisses[pixel] = 0
                } else {
                    if missingSince[pixel] < 0 { missingSince[pixel] = time }
                    misses[pixel] = min(3, misses[pixel] + 1)
                    if difference > 80 {
                        if changedSince[pixel] < 0 { changedSince[pixel] = time }
                        colorMisses[pixel] = min(2, colorMisses[pixel] + 1)
                    } else { changedSince[pixel] = -1; colorMisses[pixel] = 0 }
                    if (misses[pixel] >= 3 && time - missingSince[pixel] >= 0.20)
                        || (colorMisses[pixel] >= 2 && time - changedSince[pixel] >= 0.06) { clear(pixel) }
                }
            } else if observations[pixel] > 0 {
                clear(pixel)
            }
            // Upsample the continuous object silhouette before union with the full-size person mask.
            if confirmed[pixel] { output[pixel] = 255 }
        }
        return output
    }

    private static func personBounds(_ person: [UInt8], width: Int) -> CGRect? {
        guard let first = person.firstIndex(where: { $0 > 200 }),
              let last = person.lastIndex(where: { $0 > 200 }) else { return nil }
        var left = width, right = 0
        for pixel in first...last where person[pixel] > 200 {
            let x = pixel % width
            left = min(left, x)
            right = max(right, x)
        }
        return CGRect(x: left, y: first / width, width: right - left + 1, height: last / width - first / width + 1)
    }

    private func clear(_ pixel: Int) {
        firstSeen[pixel] = -1
        missingSince[pixel] = -1
        changedSince[pixel] = -1
        confirmed[pixel] = false
        observations[pixel] = 0
        misses[pixel] = 0
        colorMisses[pixel] = 0
    }

    private func colorDifference(_ pixel: Int, rgba: [UInt8]) -> Int {
        let i = pixel * 4
        return max(abs(Int(colors[i]) - Int(rgba[i])),
                   abs(Int(colors[i + 1]) - Int(rgba[i + 1])),
                   abs(Int(colors[i + 2]) - Int(rgba[i + 2])))
    }

    private func updateColor(_ pixel: Int, rgba: [UInt8]) {
        for channel in 0..<3 {
            let offset = pixel * 4 + channel
            colors[offset] = UInt8((Int(colors[offset]) * 3 + Int(rgba[offset]) + 2) / 4)
        }
    }
}
