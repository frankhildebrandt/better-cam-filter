import CoreGraphics
import CoreImage

enum ReactionSprite: CaseIterable {
    case bunnyHead, bunnyEar, bean, paw, heart, star, cloud, rainbow, pawPrint
}

/// Rasterizes the vector artwork once; live frames only transform and blend these images.
final class ReactionSprites {
    private let images: [ReactionSprite: CIImage]

    init() {
        images = Dictionary(uniqueKeysWithValues: ReactionSprite.allCases.map { sprite in
            (sprite, Self.makeImage(sprite))
        })
    }

    subscript(_ sprite: ReactionSprite) -> CIImage { images[sprite] ?? .empty() }

    private static func makeImage(_ sprite: ReactionSprite) -> CIImage {
        let size = sprite == .rainbow ? CGSize(width: 1024, height: 640) : CGSize(width: 512, height: 512)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .empty() }
        context.scaleBy(x: size.width / 256, y: size.height / 256)
        let drawing = ReactionDrawing(context: context)
        switch sprite {
        case .bunnyHead: drawing.bunnyHead()
        case .bunnyEar: drawing.bunnyEar()
        case .bean: drawing.bean()
        case .paw: drawing.paw()
        case .heart: drawing.heart()
        case .star: drawing.star()
        case .cloud: drawing.cloud()
        case .rainbow: drawing.rainbow()
        case .pawPrint: drawing.pawPrint()
        }
        guard let image = context.makeImage() else { return .empty() }
        return CIImage(cgImage: image)
    }
}

struct ReactionDrawing {
    let context: CGContext
    let ink = CGColor(srgbRed: 0.31, green: 0.23, blue: 0.30, alpha: 1)
    let pink = CGColor(srgbRed: 1, green: 0.64, blue: 0.76, alpha: 1)
    let cream = CGColor(srgbRed: 1, green: 0.94, blue: 0.88, alpha: 1)

    func ellipse(_ rect: CGRect, _ color: CGColor) {
        context.setFillColor(color)
        context.fillEllipse(in: rect)
    }

    func path(_ path: CGPath, fill: CGColor, outline: Bool = false) {
        context.addPath(path)
        context.setFillColor(fill)
        if outline {
            context.setStrokeColor(ink.copy(alpha: 0.45) ?? ink)
            context.setLineWidth(3)
            context.drawPath(using: .fillStroke)
        } else { context.fillPath() }
    }

    func face(at center: CGPoint, spread: CGFloat = 25, cheeks: Bool = true) {
        ellipse(CGRect(x: center.x - spread - 4, y: center.y + 2, width: 8, height: 12), ink)
        ellipse(CGRect(x: center.x + spread - 4, y: center.y + 2, width: 8, height: 12), ink)
        context.setLineCap(.round)
        context.setLineWidth(3.5)
        context.setStrokeColor(ink)
        context.move(to: CGPoint(x: center.x - 8, y: center.y - 9))
        context.addQuadCurve(to: CGPoint(x: center.x + 8, y: center.y - 9),
                             control: CGPoint(x: center.x, y: center.y - 21))
        context.strokePath()
        if cheeks {
            ellipse(CGRect(x: center.x - spread - 19, y: center.y - 12, width: 22, height: 11), pink.copy(alpha: 0.6) ?? pink)
            ellipse(CGRect(x: center.x + spread - 3, y: center.y - 12, width: 22, height: 11), pink.copy(alpha: 0.6) ?? pink)
        }
    }

    func heart() {
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: 128, y: 28))
        shape.addCurve(to: CGPoint(x: 30, y: 154), control1: CGPoint(x: 105, y: 48), control2: CGPoint(x: 30, y: 99))
        shape.addCurve(to: CGPoint(x: 128, y: 199), control1: CGPoint(x: 30, y: 220), control2: CGPoint(x: 101, y: 231))
        shape.addCurve(to: CGPoint(x: 226, y: 154), control1: CGPoint(x: 155, y: 231), control2: CGPoint(x: 226, y: 220))
        shape.addCurve(to: CGPoint(x: 128, y: 28), control1: CGPoint(x: 226, y: 99), control2: CGPoint(x: 151, y: 48))
        shape.closeSubpath()
        path(shape, fill: pink, outline: true)
        ellipse(CGRect(x: 51, y: 168, width: 16, height: 30), CGColor(gray: 1, alpha: 0.5))
        face(at: CGPoint(x: 128, y: 131))
    }

    func star() {
        let shape = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let radius: CGFloat = index.isMultiple(of: 2) ? 111 : 57
            let point = CGPoint(x: 128 + cos(angle) * radius, y: 128 + sin(angle) * radius)
            if index == 0 { shape.move(to: point) } else { shape.addLine(to: point) }
        }
        shape.closeSubpath()
        path(shape, fill: CGColor(srgbRed: 1, green: 0.82, blue: 0.36, alpha: 1))
    }
}
