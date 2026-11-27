/// Per-pixel confirmation state of accessory evidence.
/// A value type keeps the per-frame loop free of the dynamic exclusivity checks of class properties.
struct AccessoryPixelHistory {
    private(set) var confirmed = [Bool]()
    private(set) var colors = [UInt8]()
    private var firstSeen = [Double]()
    private var missingSince = [Double]()
    private var changedSince = [Double]()
    private var observations = [UInt8]()
    private var misses = [UInt8]()
    private var colorMisses = [UInt8]()

    var count: Int { confirmed.count }

    init() {}

    /// Start an empty history whose reference colors are the given frame.
    init(colors: [UInt8]) {
        let count = colors.count / 4
        confirmed = [Bool](repeating: false, count: count)
        self.colors = colors
        firstSeen = [Double](repeating: -1, count: count)
        missingSince = firstSeen
        changedSince = firstSeen
        observations = [UInt8](repeating: 0, count: count)
        misses = observations
        colorMisses = observations
    }

    /// Forget all confirmations, e.g. after a scene cut, but keep reference colors.
    mutating func clearAll() {
        for pixel in confirmed.indices { clear(pixel) }
    }

    mutating func clear(_ pixel: Int) {
        firstSeen[pixel] = -1
        missingSince[pixel] = -1
        changedSince[pixel] = -1
        confirmed[pixel] = false
        observations[pixel] = 0
        misses[pixel] = 0
        colorMisses[pixel] = 0
    }

    /// Confirm repeated evidence, retain confirmed pixels Vision covers with the same appearance,
    /// and drop pixels that stay missing or change color. Returns 255 for every confirmed pixel.
    mutating func update(evidence: [UInt8], person: [UInt8], rgba: [UInt8], inherited: [Bool], time: Double) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: evidence.count)
        for pixel in evidence.indices {
            if evidence[pixel] > 200 {
                observe(pixel, rgba: rgba, inherited: inherited[pixel], time: time)
            } else if confirmed[pixel] {
                miss(pixel, covered: person[pixel] > 200, rgba: rgba, time: time)
            } else if observations[pixel] > 0 {
                clear(pixel)
            }
            if confirmed[pixel] { output[pixel] = 255 }
        }
        return output
    }

    private mutating func observe(_ pixel: Int, rgba: [UInt8], inherited: Bool, time: Double) {
        if !confirmed[pixel] && !inherited && colorDifference(pixel, rgba: rgba) > 40 { clear(pixel) }
        if firstSeen[pixel] < 0 {
            firstSeen[pixel] = time
            for channel in 0..<3 { colors[pixel * 4 + channel] = rgba[pixel * 4 + channel] }
        }
        missingSince[pixel] = -1
        changedSince[pixel] = -1
        misses[pixel] = 0
        colorMisses[pixel] = 0
        observations[pixel] = min(3, observations[pixel] + 1)
        if inherited || (observations[pixel] >= 3 && time - firstSeen[pixel] >= 0.10) {
            confirmed[pixel] = true
        }
        if confirmed[pixel] { updateColor(pixel, rgba: rgba) }
    }

    /// A confirmed mic may merge into a dark shirt. While Vision covers
    /// the same appearance it can retain, but never create, confirmation.
    private mutating func miss(_ pixel: Int, covered: Bool, rgba: [UInt8], time: Double) {
        let difference = colorDifference(pixel, rgba: rgba)
        if covered && difference <= 24 {
            missingSince[pixel] = -1
            changedSince[pixel] = -1
            misses[pixel] = 0
            colorMisses[pixel] = 0
            return
        }
        if missingSince[pixel] < 0 { missingSince[pixel] = time }
        misses[pixel] = min(3, misses[pixel] + 1)
        if difference > 80 {
            if changedSince[pixel] < 0 { changedSince[pixel] = time }
            colorMisses[pixel] = min(2, colorMisses[pixel] + 1)
        } else {
            changedSince[pixel] = -1
            colorMisses[pixel] = 0
        }
        if (misses[pixel] >= 3 && time - missingSince[pixel] >= 0.20)
            || (colorMisses[pixel] >= 2 && time - changedSince[pixel] >= 0.06) { clear(pixel) }
    }

    private func colorDifference(_ pixel: Int, rgba: [UInt8]) -> Int {
        let i = pixel * 4
        return max(abs(Int(colors[i]) - Int(rgba[i])),
                   abs(Int(colors[i + 1]) - Int(rgba[i + 1])),
                   abs(Int(colors[i + 2]) - Int(rgba[i + 2])))
    }

    private mutating func updateColor(_ pixel: Int, rgba: [UInt8]) {
        for channel in 0..<3 {
            let offset = pixel * 4 + channel
            colors[offset] = UInt8((Int(colors[offset]) * 3 + Int(rgba[offset]) + 2) / 4)
        }
    }
}
