import Foundation

struct AccessoryProposal {
    let alpha: [UInt8]
    let evidence: [UInt8]
    let metalPixels: [Int]
}

struct AccessorySamples {
    let rgba: [UInt8]
    let alpha: [UInt8]
    let width: Int
    let height: Int

    func proposal(collectMetal: Bool = false) -> AccessoryProposal {
        AccessoryRegions.propose(rgba: rgba, alpha: alpha, width: width, height: height, collectMetal: collectMetal)
    }
}

/// Bounded appearance-based additions anchored to the semantic foreground mask.
enum AccessoryRegions {
    private static let dark: UInt8 = 1
    // Labels 2...13 are the cable hue bins.
    private static let midtone: UInt8 = 14
    private static let highlight: UInt8 = 15

    private struct Candidate {
        let pixels: [Int]
        let material: UInt8
        let slender: Bool
        let touchesTop: Bool

        init?(_ pixels: [Int], material: UInt8, width: Int, count: Int) {
            guard pixels.count >= 4 else { return nil }
            if material == highlight && pixels.count > max(4, count / 500) { return nil }
            var left = width, right = 0, top = Int.max, bottom = 0
            for pixel in pixels {
                let x = pixel % width, y = pixel / width
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
            }
            let length = max(right - left + 1, bottom - top + 1)
            slender = Double(pixels.count) / Double(length) <= max(2, Double(width) * 0.014)
            if material == dark {
                guard pixels.count >= max(4, count / 500) || (length >= max(8, width / 25) && slender) else { return nil }
            } else if material == highlight {
                guard length <= max(3, width / 20) else { return nil }
            } else {
                guard slender && (material != midtone || length <= width / 6) else { return nil }
            }
            self.pixels = pixels
            self.material = material
            touchesTop = top < 2
        }
    }

    static func refine(rgba: [UInt8], alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        propose(rgba: rgba, alpha: alpha, width: width, height: height).alpha
    }

    static func restoreMetal(from coarse: AccessorySamples, in fine: AccessorySamples, evidence: inout [UInt8]) {
        let metal = coarse.proposal(collectMetal: true).metalPixels
        guard !metal.isEmpty else { return }
        // Partition fine pixel centers by their nearest coarse sample, also for 768:512.
        func boundaries(_ source: Int, _ target: Int) -> [Int] {
            (0...source).map { (2 * $0 * target + source - 1) / (2 * source) }
        }
        let columns = boundaries(coarse.width, fine.width)
        let rows = boundaries(coarse.height, fine.height)
        for source in metal {
            let x = source % coarse.width, y = source / coarse.width, reference = source * 4
            for row in rows[y]..<rows[y + 1] {
                for column in columns[x]..<columns[x + 1] {
                    let pixel = row * fine.width + column, offset = pixel * 4
                    guard evidence[pixel] == 0, category(fine.rgba, at: offset) >= midtone else { continue }
                    // Reject mixed edge samples where the coarse pixel overlaps the room.
                    if (0..<3).allSatisfy({ abs(Int(fine.rgba[offset + $0]) - Int(coarse.rgba[reference + $0])) <= 28 }) {
                        evidence[pixel] = 255
                    }
                }
            }
        }
    }

    /// Track approved components independently of which pixels Vision already calls foreground.
    static func propose(rgba: [UInt8], alpha: [UInt8], width: Int, height: Int,
                        collectMetal: Bool = false) -> AccessoryProposal {
        let empty = AccessoryProposal(alpha: alpha, evidence: [UInt8](repeating: 0, count: alpha.count), metalPixels: [])
        guard width > 0, height > 0 else { return empty }
        let count = alpha.count
        guard count / width == height, count % width == 0, rgba.count / 4 == count, rgba.count % 4 == 0
        else { return empty }
        guard let first = alpha.firstIndex(where: { $0 > 200 }), let last = alpha.lastIndex(where: { $0 > 200 })
        else { return empty }
        let top = first / width, bottom = last / width
        let personArea = alpha[first...last].count(where: { $0 > 200 })
        let categories = (0..<count).map { category(rgba, at: $0 * 4) }
        let candidates = PixelComponents.regions(categories, width: width, height: height).compactMap {
            Candidate($0, material: categories[$0[0]], width: width, count: count)
        }
        let torsoStart = top + (bottom - top) * 55 / 100
        var result = alpha
        var evidence = empty.evidence
        var metalPixels = [Int]()
        var anchors = alpha
        for pixel in 0..<(torsoStart * width) { anchors[pixel] = 0 }
        var accepted = Set<Int>()
        var remaining = count / 4
        let reach = min(254, max(2, Int((Double(width) * 0.025).rounded())))
        // Each pass can cross one material boundary, e.g. boom, plug, cable.
        let maxPasses = 4
        for pass in 0..<maxPasses {
            let proximity = distances(from: anchors, width: width, height: height, reach: reach)
            let previousCount = accepted.count
            for (identifier, candidate) in candidates.enumerated() where !accepted.contains(identifier) {
                guard candidate.material != highlight, pass < 2 || candidate.slender else { continue }
                let region = candidate.pixels
                let added = region.filter { alpha[$0] < 128 && result[$0] < 128 }
                guard added.count <= min(count / 5, remaining),
                      !added.contains(where: { $0 / width < 2 }) else { continue }
                guard let contact = region.min(by: { proximity.distance[$0] < proximity.distance[$1] }),
                      Int(proximity.distance[contact]) <= reach else { continue }
                // Gray highlights can complete an attached barrel. A nearby patch
                // of wall must not become an independent accessory.
                if candidate.material == midtone {
                    guard pass > 0, proximity.distance[contact] <= 1,
                          touchesHardware(region, categories: categories, evidence: evidence, width: width, height: height)
                    else { continue }
                }
                let requiredSupport = max(2, width / 100)
                let support = region.lazy.filter { Int(proximity.distance[$0]) <= reach }.prefix(requiredSupport).count
                guard support >= requiredSupport else { continue }
                accepted.insert(identifier)
                remaining -= added.count
                // A small, torso-anchored component can be the capsule all the way up
                // to the mouth, including when Vision puts it inside the person mask.
                // Keep the upper part of a body-sized component out of the history.
                let accessorySized = region.count <= personArea / 3 && !candidate.touchesTop
                for pixel in region {
                    result[pixel] = 255
                    if accessorySized || alpha[pixel] < 128 || pixel / width >= torsoStart { evidence[pixel] = 255 }
                    if pass + 1 < maxPasses && anchors[pixel] <= 200
                        && (pixel / width >= torsoStart || (candidate.slender && alpha[pixel] < 128)) {
                        anchors[pixel] = 255
                    }
                }
                if collectMetal && candidate.material == midtone {
                    metalPixels.append(contentsOf: region.filter { evidence[$0] > 200 })
                }
                if proximity.distance[contact] > 0 {
                    let anchor = Int(proximity.anchor[contact])
                    let radius = max(1, Int(Double(width) * (candidate.material == dark ? 0.009 : 0.003)))
                    bridge(from: contact, to: anchor, radius: radius, alpha: &result,
                           evidence: &evidence, original: alpha, remaining: &remaining, width: width, height: height)
                }
            }
            if accepted.count == previousCount || accepted.count == candidates.count { break }
        }
        // A specular reflection can be almost white. Complete only compact islands
        // enclosed by accepted hardware, leaving the gaps between separate rails open.
        for candidate in candidates where candidate.material == highlight {
            let region = candidate.pixels
            guard region.count <= remaining,
                  enclosedByHardware(region, categories: categories, evidence: evidence, width: width, height: height)
            else { continue }
            for pixel in region {
                if result[pixel] < 128 { remaining -= 1 }
                result[pixel] = 255
                evidence[pixel] = 255
            }
            if collectMetal { metalPixels.append(contentsOf: region) }
        }
        return AccessoryProposal(alpha: result, evidence: evidence, metalPixels: metalPixels)
    }

    private static func touchesHardware(_ pixels: [Int], categories: [UInt8], evidence: [UInt8],
                                        width: Int, height: Int) -> Bool {
        for pixel in pixels {
            let x = pixel % width, y = pixel / width
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    let neighbor = ny * width + nx
                    if evidence[neighbor] > 200 && (dark..<midtone).contains(categories[neighbor]) { return true }
                }
            }
        }
        return false
    }

    private static func enclosedByHardware(_ pixels: [Int], categories: [UInt8], evidence: [UInt8],
                                           width: Int, height: Int) -> Bool {
        var border = 0, supported = 0, metal = 0
        for pixel in pixels {
            let x = pixel % width, y = pixel / width
            guard x > 0, x + 1 < width, y > 0, y + 1 < height else { return false }
            for neighbor in [pixel - 1, pixel + 1, pixel - width, pixel + width] where categories[neighbor] != highlight {
                border += 1
                if evidence[neighbor] > 200 {
                    supported += 1
                    if categories[neighbor] == midtone { metal += 1 }
                }
            }
        }
        return border > 0 && supported * 4 >= border * 3 && metal * 2 >= border
    }

    private static func category(_ rgba: [UInt8], at offset: Int) -> UInt8 {
        let r = Double(rgba[offset]) / 255
        let g = Double(rgba[offset + 1]) / 255
        let b = Double(rgba[offset + 2]) / 255
        let high = max(r, g, b), low = min(r, g, b)
        let chroma = high - low
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (luma < 0.33 && chroma < 0.22) || luma < 0.10 { return dark }
        if chroma < 0.14 { return luma < 0.76 ? midtone : highlight }
        guard chroma > 0.22, chroma / max(high, 0.001) > 0.4 else { return 0 }
        let hue: Double
        if high == r { hue = ((g - b) / chroma).truncatingRemainder(dividingBy: 6) }
        else if high == g { hue = (b - r) / chroma + 2 }
        else { hue = (r - g) / chroma + 4 }
        return UInt8(Int(((hue + 6) * 2).rounded(.down)) % 12 + 2)
    }

    private static func distances(from alpha: [UInt8], width: Int, height: Int, reach: Int)
        -> (distance: [UInt8], anchor: [Int32]) {
        var distance = [UInt8](repeating: 255, count: alpha.count)
        var anchor = [Int32](repeating: -1, count: alpha.count)
        // Only pixels within reach of an anchor can contribute. Start a wave at
        // the silhouette boundary; the room and interior need no neighbor search.
        var frontier = [Int]()
        for pixel in alpha.indices where alpha[pixel] > 200 {
            distance[pixel] = 0
            anchor[pixel] = Int32(pixel)
            let x = pixel % width
            if (x > 0 && alpha[pixel - 1] <= 200)
                || (x + 1 < width && alpha[pixel + 1] <= 200)
                || (pixel >= width && alpha[pixel - width] <= 200)
                || (pixel + width < alpha.count && alpha[pixel + width] <= 200) {
                frontier.append(pixel)
            }
        }
        var cursor = 0
        for step in 1...reach {
            let end = frontier.count
            guard cursor < end else { break }
            let nextDistance = UInt8(step)
            while cursor < end {
                let pixel = frontier[cursor]
                cursor += 1
                let x = pixel % width, y = pixel / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = ny * width + nx
                        if distance[next] > nextDistance {
                            distance[next] = nextDistance
                            anchor[next] = anchor[pixel]
                            if step < reach { frontier.append(next) }
                        } else if distance[next] == nextDistance && anchor[next] != anchor[pixel],
                                  squaredDistance(next, Int(anchor[pixel]), width: width)
                                    < squaredDistance(next, Int(anchor[next]), width: width) {
                            anchor[next] = anchor[pixel]
                        }
                    }
                }
            }
        }
        return (distance, anchor)
    }

    private static func squaredDistance(_ a: Int, _ b: Int, width: Int) -> Int {
        let dx = a % width - b % width, dy = a / width - b / width
        return dx * dx + dy * dy
    }

    private static func bridge(from start: Int, to end: Int, radius: Int, alpha: inout [UInt8],
                               evidence: inout [UInt8], original: [UInt8], remaining: inout Int, width: Int, height: Int) {
        let x0 = start % width, y0 = start / width, x1 = end % width, y1 = end / width
        let steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for step in 0...steps {
            let x = x0 + (x1 - x0) * step / steps, y = y0 + (y1 - y0) * step / steps
            for ny in max(0, y - radius)...min(height - 1, y + radius) {
                for nx in max(0, x - radius)...min(width - 1, x + radius)
                where (nx - x) * (nx - x) + (ny - y) * (ny - y) <= radius * radius {
                    let pixel = ny * width + nx
                    if original[pixel] < 128 && alpha[pixel] < 128 {
                        guard remaining > 0 else { continue }
                        remaining -= 1
                    }
                    alpha[pixel] = 255
                    evidence[pixel] = 255
                }
            }
        }
    }
}
