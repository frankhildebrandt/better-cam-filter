import CoreGraphics
import Foundation

struct KeepStroke: Identifiable, Sendable {
    let id = UUID()
    /// Points use normalized preview coordinates with the origin at the top left.
    var points: [CGPoint]
    let radius: CGFloat
}

enum KeepMask {
    /// Rasterize only when editing changes, never once per video frame.
    static func render(_ strokes: [KeepStroke], width: Int = 960, height: Int = 540) -> CGImage? {
        guard !strokes.isEmpty,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(gray: 1, alpha: 1)
        context.setFillColor(gray: 1, alpha: 1)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let radius = stroke.radius * CGFloat(width)
            let start = pixelPoint(first, width: width, height: height)
            context.setLineWidth(radius * 2)
            context.fillEllipse(in: CGRect(x: start.x - radius, y: start.y - radius, width: radius * 2, height: radius * 2))
            context.beginPath()
            context.move(to: start)
            for point in stroke.points.dropFirst() {
                context.addLine(to: pixelPoint(point, width: width, height: height))
            }
            context.strokePath()
        }
        return context.makeImage()
    }

    private static func pixelPoint(_ point: CGPoint, width: Int, height: Int) -> CGPoint {
        CGPoint(x: point.x * CGFloat(width), y: (1 - point.y) * CGFloat(height))
    }
}
