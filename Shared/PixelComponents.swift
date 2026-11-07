/// Eight-connected regions of equal nonzero labels.
enum PixelComponents {
    static func regions(_ categories: [UInt8], width: Int, height: Int) -> [[Int]] {
        var visited = [Bool](repeating: false, count: categories.count)
        var regions = [[Int]]()
        for start in categories.indices where categories[start] != 0 && !visited[start] {
            var pixels = [start]
            visited[start] = true
            var cursor = 0
            while cursor < pixels.count {
                let pixel = pixels[cursor]
                cursor += 1
                let x = pixel % width, y = pixel / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = ny * width + nx
                        if !visited[neighbor] && categories[neighbor] == categories[start] {
                            visited[neighbor] = true
                            pixels.append(neighbor)
                        }
                    }
                }
            }
            regions.append(pixels)
        }
        return regions
    }
}
