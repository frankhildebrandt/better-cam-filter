import CoreGraphics

/// Confirm object evidence even during semantic coverage; never use person alpha itself as evidence.
final class AccessoryTemporalFilter {
    private var history = AccessoryPixelHistory()
    private var scene = AccessorySceneHistory()
    private var dimensions = (width: 0, height: 0)
    private var lastTime: Double?
    private var previousPersonBounds = CGRect.null

    func reset() {
        history = AccessoryPixelHistory()
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
            history = AccessoryPixelHistory(colors: rgba)
            dimensions = (width, height)
        }
        guard let bounds = Self.personBounds(person, width: width) else {
            reset()
            return [UInt8](repeating: 0, count: count)
        }
        let margin = CGFloat(max(2, width / 5))
        let relocated = !previousPersonBounds.isNull
            && !bounds.insetBy(dx: -margin, dy: -margin).intersects(previousPersonBounds)
        if scene.changed(rgba: rgba, person: person, evidence: evidence, confirmed: history.confirmed) || relocated {
            history.clearAll()
        }
        previousPersonBounds = bounds
        lastTime = time
        let motion = AccessoryMotionSupport.transfer(evidence: evidence, confirmed: history.confirmed,
                                                     colors: history.colors, rgba: rgba, width: width, height: height)
        for pixel in motion.vacated { history.clear(pixel) }
        // Upsample the continuous object silhouette before union with the full-size person mask.
        return history.update(evidence: evidence, person: person, rgba: rgba, inherited: motion.inherited, time: time)
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
}
