/// Eight-connected regions of equal nonzero labels.
enum PixelComponents {
    static func regions(_ categories: [UInt8], width: Int, height: Int) -> [[Int]] {
        var unvisited = categories
        var regions = [[Int]]()
        for start in categories.indices where unvisited[start] != 0 {
            let label = unvisited[start]
            var pixels = [Int]()
            var runs = [Range<Int>]()

            // Consume each horizontal run once. Only its two adjacent rows can
            // contain new neighbors, including diagonals at either end.
            func takeRun(at pixel: Int) -> Int {
                let row = pixel / width * width
                var left = pixel, end = pixel + 1
                while left > row && unvisited[left - 1] == label { left -= 1 }
                while end < row + width && unvisited[end] == label { end += 1 }
                let run = left..<end
                for index in run { unvisited[index] = 0 }
                pixels.append(contentsOf: run)
                runs.append(run)
                return end
            }

            _ = takeRun(at: start)
            var cursor = 0
            while cursor < runs.count {
                let run = runs[cursor]
                cursor += 1
                let row = run.lowerBound / width
                let left = max(0, run.lowerBound % width - 1)
                let end = min(width, (run.upperBound - 1) % width + 2)
                for neighbor in [row - 1, row + 1] where neighbor >= 0 && neighbor < height {
                    var next = neighbor * width + left
                    let limit = neighbor * width + end
                    while next < limit {
                        if unvisited[next] == label { next = takeRun(at: next) }
                        else { next += 1 }
                    }
                }
            }
            regions.append(pixels)
        }
        return regions
    }
}
