import Foundation

struct AccessoryProposal {
    let alpha: [UInt8]
    let evidence: [UInt8]
}

/// Bounded appearance-based additions anchored to the semantic foreground mask.
enum AccessoryRegions {
    static func refine(rgba: [UInt8], alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        propose(rgba: rgba, alpha: alpha, width: width, height: height).alpha
    }

    /// Track approved components independently of which pixels Vision already calls foreground.
    static func propose(rgba: [UInt8], alpha: [UInt8], width: Int, height: Int) -> AccessoryProposal {
        let empty = AccessoryProposal(alpha: alpha, evidence: [UInt8](repeating: 0, count: alpha.count))
        guard width > 0, height > 0 else { return empty }
        let count = width * height
        guard rgba.count == count * 4, alpha.count == count else { return empty }
        let categories = (0..<count).map { category(rgba, at: $0 * 4) }
        let regions = PixelComponents.regions(categories, width: width, height: height)
        let person = alpha.indices.filter { alpha[$0] > 200 }
        guard let top = person.map({ $0 / width }).min(), let bottom = person.map({ $0 / width }).max() else { return empty }
        let torsoStart = top + (bottom - top) * 55 / 100
        var torsoSeeds = alpha
        for pixel in alpha.indices where pixel / width < torsoStart { torsoSeeds[pixel] = 0 }
        var result = alpha
        var evidence = empty.evidence
        var anchors = torsoSeeds
        var accepted = Set<Int>()
        var remaining = count / 4
        let reach = max(2, Int((Double(width) * 0.025).rounded()))
        for _ in 0..<2 {
            let proximity = distances(from: anchors, width: width, height: height, reach: reach)
            for (identifier, region) in regions.enumerated() where !accepted.contains(identifier) {
                guard region.count >= 4 else { continue }
                if categories[region[0]] == 1 && region.count < max(4, count / 500) { continue }
                let added = region.filter { alpha[$0] < 128 && result[$0] < 128 }
                guard added.count <= min(count / 5, remaining),
                      !added.contains(where: { $0 / width < 2 }) else { continue }
                if categories[region[0]] > 1 {
                    let xs = region.map { $0 % width }
                    let ys = region.map { $0 / width }
                    let length = max(xs.max()! - xs.min()! + 1, ys.max()! - ys.min()! + 1)
                    guard Double(region.count) / Double(length) <= max(2, Double(width) * 0.014) else { continue }
                }
                guard let contact = region.min(by: { proximity.distance[$0] < proximity.distance[$1] }),
                      Int(proximity.distance[contact]) <= reach else { continue }
                let requiredSupport = max(2, width / 100)
                let support = region.lazy.filter { Int(proximity.distance[$0]) <= reach }.prefix(requiredSupport).count
                guard support >= requiredSupport else { continue }
                accepted.insert(identifier)
                remaining -= added.count
                for pixel in region {
                    result[pixel] = 255
                    if alpha[pixel] < 128 || pixel / width >= torsoStart { evidence[pixel] = 255 }
                    if pixel / width >= torsoStart { anchors[pixel] = 255 }
                }
                if proximity.distance[contact] > 0 {
                    let anchor = Int(proximity.anchor[contact])
                    let radius = max(1, Int(Double(width) * (categories[region[0]] == 1 ? 0.009 : 0.003)))
                    bridge(from: contact, to: anchor, radius: radius, alpha: &result,
                           evidence: &evidence, original: alpha, remaining: &remaining, width: width, height: height)
                }
            }
        }
        return AccessoryProposal(alpha: result, evidence: evidence)
    }

    private static func category(_ rgba: [UInt8], at offset: Int) -> UInt8 {
        let r = Double(rgba[offset]) / 255
        let g = Double(rgba[offset + 1]) / 255
        let b = Double(rgba[offset + 2]) / 255
        let high = max(r, g, b), low = min(r, g, b)
        let chroma = high - low
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (luma < 0.33 && chroma < 0.22) || luma < 0.10 { return 1 }
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
        for pixel in alpha.indices where alpha[pixel] > 200 {
            distance[pixel] = 0
            anchor[pixel] = Int32(pixel)
        }
        for pixel in alpha.indices {
            let x = pixel % width, y = pixel / width
            if x > 0 { relax(pixel, from: pixel - 1, width: width, reach: reach, distance: &distance, anchor: &anchor) }
            if y > 0 {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    relax(pixel, from: (y - 1) * width + nx, width: width, reach: reach, distance: &distance, anchor: &anchor)
                }
            }
        }
        for pixel in alpha.indices.reversed() {
            let x = pixel % width, y = pixel / width
            if x < width - 1 { relax(pixel, from: pixel + 1, width: width, reach: reach, distance: &distance, anchor: &anchor) }
            if y < height - 1 {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    relax(pixel, from: (y + 1) * width + nx, width: width, reach: reach, distance: &distance, anchor: &anchor)
                }
            }
        }
        return (distance, anchor)
    }

    private static func relax(_ pixel: Int, from neighbor: Int, width: Int, reach: Int,
                              distance: inout [UInt8], anchor: inout [Int32]) {
        guard distance[neighbor] < reach else { return }
        let candidate = distance[neighbor] + 1
        let closerAnchor = candidate == distance[pixel]
            && squaredDistance(pixel, Int(anchor[neighbor]), width: width)
                < squaredDistance(pixel, Int(anchor[pixel]), width: width)
        if candidate < distance[pixel] || closerAnchor {
            distance[pixel] = distance[neighbor] + 1
            anchor[pixel] = anchor[neighbor]
        }
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
