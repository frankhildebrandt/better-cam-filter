/// Carry confirmation across overlapping objects and short, verified cable displacements.
enum AccessoryMotionSupport {
    struct Transfer {
        var inherited: [Bool]
        var vacated = [Int]()
    }

    static func transfer(evidence: [UInt8], confirmed: [Bool], colors: [UInt8], rgba: [UInt8],
                         width: Int, height: Int) -> Transfer {
        var result = Transfer(inherited: [Bool](repeating: false, count: evidence.count))
        // Only new pixels need to inherit. A stationary component has none.
        guard confirmed.contains(true),
              evidence.indices.contains(where: { evidence[$0] > 200 && !confirmed[$0] }) else { return result }
        let labels = evidence.map { UInt8($0 > 200 ? 1 : 0) }
        var distance = [Int](repeating: -1, count: evidence.count)
        var source = [Int](repeating: -1, count: evidence.count)
        let reach = max(2, width / 50)
        for region in PixelComponents.regions(labels, width: width, height: height) {
            var anchors = region.filter { pixel in
                confirmed[pixel] && matches(colors, pixel, rgba, pixel, tolerance: 40)
            }
            guard anchors.count >= 2, anchors.count * 5 >= region.count * 2 else { continue }
            for pixel in anchors { distance[pixel] = 0; source[pixel] = pixel }
            var cursor = 0
            while cursor < anchors.count {
                let pixel = anchors[cursor]
                cursor += 1
                result.inherited[pixel] = true
                guard distance[pixel] < reach else { continue }
                let x = pixel % width, y = pixel / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = ny * width + nx
                        guard labels[neighbor] != 0, distance[neighbor] < 0 else { continue }
                        if matches(colors, source[pixel], rgba, neighbor, tolerance: 40) {
                            distance[neighbor] = distance[pixel] + 1
                            source[neighbor] = source[pixel]
                            anchors.append(neighbor)
                        }
                    }
                }
            }
        }
        transferShiftedCables(evidence: evidence, confirmed: confirmed, colors: colors, rgba: rgba,
                              width: width, height: height, result: &result)
        return result
    }

    // A narrow cable can move by its entire thickness between frames. Look for
    // the same strip at a single offset only when its old location changed.
    private static func transferShiftedCables(evidence: [UInt8], confirmed: [Bool], colors: [UInt8], rgba: [UInt8],
                                              width: Int, height: Int, result: inout Transfer) {
        let lost = evidence.indices.map { pixel in
            UInt8(confirmed[pixel] && evidence[pixel] <= 200 && !matches(colors, pixel, rgba, pixel, tolerance: 60) ? 1 : 0)
        }
        let radius = max(2, width / 85)
        for strip in PixelComponents.regions(lost, width: width, height: height) where strip.count >= 6 {
            let xs = strip.map { $0 % width }, ys = strip.map { $0 / width }
            let left = xs.min()!, right = xs.max()!, top = ys.min()!, bottom = ys.max()!
            let span = max(right - left, bottom - top) + 1
            guard span >= max(6, width / 50), strip.count <= span * max(2, width / 100) else { continue }
            let samples = stride(from: 0, to: strip.count, by: max(1, (strip.count + 23) / 24)).map { strip[$0] }
            var bestScore = 0, bestDistance = Int.max, bestOffset = 0
            for dy in max(-top, -radius)...min(height - 1 - bottom, radius) {
                for dx in max(-left, -radius)...min(width - 1 - right, radius) {
                    let offset = dy * width + dx
                    let score = samples.count { source in
                        let target = source + offset
                        return evidence[target] > 200 && !confirmed[target] && matches(colors, source, rgba, target, tolerance: 32)
                    }
                    let distance = dx * dx + dy * dy
                    if score > bestScore || (score == bestScore && distance < bestDistance) {
                        bestScore = score
                        bestDistance = distance
                        bestOffset = offset
                    }
                }
            }
            guard bestScore * 4 >= samples.count * 3 else { continue }
            for source in strip {
                let target = source + bestOffset
                if evidence[target] > 200 && !confirmed[target] && matches(colors, source, rgba, target, tolerance: 32) {
                    result.inherited[target] = true
                    result.vacated.append(source)
                }
            }
        }
    }

    private static func matches(_ reference: [UInt8], _ p: Int, _ current: [UInt8], _ q: Int, tolerance: Int) -> Bool {
        (0..<3).allSatisfy { abs(Int(reference[p * 4 + $0]) - Int(current[q * 4 + $0])) <= tolerance }
    }
}
