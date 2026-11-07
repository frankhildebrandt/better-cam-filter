/// Carry confirmation only across a small movement of a substantially overlapping component.
enum AccessoryMotionSupport {
    static func inherited(evidence: [UInt8], confirmed: [Bool], colors: [UInt8], rgba: [UInt8],
                          width: Int, height: Int) -> [Bool] {
        let labels = evidence.map { UInt8($0 > 200 ? 1 : 0) }
        var result = [Bool](repeating: false, count: evidence.count)
        var distance = [Int](repeating: -1, count: evidence.count)
        var source = [Int](repeating: -1, count: evidence.count)
        let reach = max(2, width / 50)
        for region in PixelComponents.regions(labels, width: width, height: height) {
            var anchors = region.filter { pixel in
                confirmed[pixel] && (0..<3).allSatisfy {
                    abs(Int(colors[pixel * 4 + $0]) - Int(rgba[pixel * 4 + $0])) <= 40
                }
            }
            guard anchors.count >= 2, anchors.count * 5 >= region.count * 2 else { continue }
            for pixel in anchors { distance[pixel] = 0; source[pixel] = pixel }
            var cursor = 0
            while cursor < anchors.count {
                let pixel = anchors[cursor]
                cursor += 1
                result[pixel] = true
                guard distance[pixel] < reach else { continue }
                let x = pixel % width, y = pixel / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = ny * width + nx
                        let matchesAnchor = (0..<3).allSatisfy {
                            abs(Int(colors[source[pixel] * 4 + $0]) - Int(rgba[neighbor * 4 + $0])) <= 40
                        }
                        if labels[neighbor] != 0 && distance[neighbor] < 0 && matchesAnchor {
                            distance[neighbor] = distance[pixel] + 1
                            source[neighbor] = source[pixel]
                            anchors.append(neighbor)
                        }
                    }
                }
            }
        }
        return result
    }
}
