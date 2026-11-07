import Foundation

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
        if scene.changed(rgba: rgba, person: person, evidence: evidence, confirmed: confirmed) {
            for pixel in evidence.indices { clear(pixel) }
        }
        lastTime = time
        let seeds = person.indices.filter { person[$0] > 200 }
        guard let minX = seeds.map({ $0 % width }).min(), let maxX = seeds.map({ $0 % width }).max(),
              let minY = seeds.map({ $0 / width }).min(), let maxY = seeds.map({ $0 / width }).max() else {
            reset()
            return [UInt8](repeating: 0, count: count)
        }
        let margin = max(2, width / 5)
        let inherited = AccessoryMotionSupport.inherited(evidence: evidence, confirmed: confirmed,
                                                        colors: colors, rgba: rgba, width: width, height: height)
        var output = [UInt8](repeating: 0, count: count)
        for pixel in evidence.indices {
            if evidence[pixel] > 200 {
                if !confirmed[pixel] && !inherited[pixel] && colorDifference(pixel, rgba: rgba) > 40 { clear(pixel) }
                if firstSeen[pixel] < 0 {
                    firstSeen[pixel] = time
                    for channel in 0..<3 { colors[pixel * 4 + channel] = rgba[pixel * 4 + channel] }
                }
                missingSince[pixel] = -1
                changedSince[pixel] = -1
                misses[pixel] = 0
                colorMisses[pixel] = 0
                observations[pixel] = min(3, observations[pixel] + 1)
                if inherited[pixel] || (observations[pixel] >= 3 && time - firstSeen[pixel] >= 0.10) {
                    confirmed[pixel] = true
                }
                if confirmed[pixel] { updateColor(pixel, rgba: rgba) }
            } else {
                firstSeen[pixel] = -1
                observations[pixel] = 0
                let x = pixel % width, y = pixel / width
                let nearby = x >= minX - margin && x <= maxX + margin
                    && y >= minY && y <= maxY + margin
                if !confirmed[pixel] || !nearby { clear(pixel) }
                else {
                    if missingSince[pixel] < 0 { missingSince[pixel] = time }
                    misses[pixel] = min(3, misses[pixel] + 1)
                    let missingTime = time - missingSince[pixel]
                    if colorDifference(pixel, rgba: rgba) > 80 {
                        if changedSince[pixel] < 0 { changedSince[pixel] = time }
                        colorMisses[pixel] = min(2, colorMisses[pixel] + 1)
                    } else { changedSince[pixel] = -1; colorMisses[pixel] = 0 }
                    if (misses[pixel] >= 3 && missingTime >= 0.20)
                        || (colorMisses[pixel] >= 2 && time - changedSince[pixel] >= 0.06) { clear(pixel) }
                }
            }
            // Semantic coverage hides the overlay while retaining its independent object confirmation.
            if confirmed[pixel] && person[pixel] < 255 { output[pixel] = 255 }
        }
        return output
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
        (0..<3).map { abs(Int(colors[pixel * 4 + $0]) - Int(rgba[pixel * 4 + $0])) }.max() ?? 0
    }

    private func updateColor(_ pixel: Int, rgba: [UInt8]) {
        for channel in 0..<3 {
            let offset = pixel * 4 + channel
            colors[offset] = UInt8((Int(colors[offset]) * 3 + Int(rgba[offset]) + 2) / 4)
        }
    }
}
