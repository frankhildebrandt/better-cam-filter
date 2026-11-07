import CoreImage
import Foundation

struct ReactionLayers {
    let foreground: CIImage?
    let background: CIImage?

    static var empty: Self { Self(foreground: nil, background: nil) }
}

/// Builds short, deterministic animations on the frame processor's serial queue.
final class ReactionRenderer {
    private let sprites = ReactionSprites()

    func frame(reaction: ReactionKind, progress: Double, anchor: CGPoint, bounds: CGRect) -> ReactionLayers {
        guard progress.isFinite, progress > 0, progress < 1,
              anchor.x.isFinite, anchor.y.isFinite, !bounds.isEmpty, !bounds.isInfinite,
              bounds.origin.x.isFinite, bounds.origin.y.isFinite,
              bounds.width.isFinite, bounds.height.isFinite else { return .empty }
        let scene = ReactionScene(sprites: sprites, progress: progress, anchor: anchor, bounds: bounds)
        let layers: ReactionLayers
        switch reaction {
        case .bunnyPeek: layers = scene.bunny()
        case .goodBean: layers = scene.bean()
        case .pawFive: layers = scene.paw()
        case .lovePuff: layers = scene.love()
        case .rainbowYay: layers = scene.rainbow()
        case .tinyLove: layers = scene.tinyLove()
        }
        let fade = scene.smooth(min(progress / 0.10, (1 - progress) / 0.18, 1))
        return ReactionLayers(foreground: layers.foreground.map { scene.faded($0, opacity: fade).cropped(to: bounds) },
                              background: layers.background.map { scene.faded($0, opacity: fade).cropped(to: bounds) })
    }
}

struct ReactionScene {
    let sprites: ReactionSprites
    let progress: Double
    let anchor: CGPoint
    let bounds: CGRect

    var unit: CGFloat { min(bounds.height, bounds.width) }
    var phase: CGFloat { CGFloat(progress) }
    var point: CGPoint {
        CGPoint(x: bounds.minX + min(0.85, max(0.15, anchor.x)) * bounds.width,
                y: bounds.minY + min(0.78, max(0.22, anchor.y)) * bounds.height)
    }

    func smooth(_ value: Double) -> Double {
        let amount = min(1, max(0, value))
        return amount * amount * (3 - 2 * amount)
    }

    func faded(_ image: CIImage, opacity: Double) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
        ])
    }

    func placed(_ sprite: ReactionSprite, width: CGFloat, at center: CGPoint,
                angle: CGFloat = 0, opacity: Double = 1) -> CIImage {
        let source = sprites[sprite]
        guard source.extent.width > 0 else { return .empty() }
        let scale = width / source.extent.width
        let image = source
            .transformed(by: CGAffineTransform(translationX: -source.extent.midX, y: -source.extent.midY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(rotationAngle: angle))
            .transformed(by: CGAffineTransform(translationX: center.x, y: center.y))
        return opacity < 1 ? faded(image, opacity: opacity) : image
    }

    func merged(_ images: [CIImage]) -> CIImage {
        images.reduce(CIImage.empty()) { $1.composited(over: $0) }
    }

    func front(_ image: CIImage) -> ReactionLayers { ReactionLayers(foreground: image, background: nil) }

    func bunny() -> ReactionLayers {
        let entrance = CGFloat(smooth(progress / 0.19))
        let exit = CGFloat(smooth((1 - progress) / 0.20))
        let base = CGPoint(x: point.x, y: bounds.minY - unit * 0.18 + unit * 0.30 * min(entrance, exit))
        let wiggle = sin(phase * .pi * 9) * 0.12
        return front(merged([
            placed(.bunnyEar, width: unit * 0.15,
                   at: CGPoint(x: base.x - unit * 0.043, y: base.y + unit * 0.12), angle: 0.17 + wiggle),
            placed(.bunnyEar, width: unit * 0.15,
                   at: CGPoint(x: base.x + unit * 0.043, y: base.y + unit * 0.12), angle: -0.17 - wiggle),
            placed(.bunnyHead, width: unit * 0.25, at: base)
        ]))
    }

    func bean() -> ReactionLayers {
        let side: CGFloat = anchor.x > 0.5 ? -1 : 1
        let bounce = abs(sin(phase * .pi * 3)) * unit * 0.045
        let center = CGPoint(x: point.x + side * unit * 0.12, y: point.y + unit * 0.08 + bounce)
        var images = [placed(.bean, width: unit * 0.20, at: center, angle: sin(phase * .pi * 6) * 0.10)]
        for index in 0..<3 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            let distance = unit * (0.12 + 0.045 * phase)
            let sparkle = 0.75 + 0.25 * sin(phase * .pi * 6 + CGFloat(index))
            images.append(placed(.star, width: unit * 0.042 * sparkle,
                                 at: CGPoint(x: center.x + cos(angle) * distance,
                                             y: center.y + sin(angle) * distance), angle: phase + angle))
        }
        return front(merged(images))
    }

    func paw() -> ReactionLayers {
        let approach = CGFloat(smooth(progress / 0.24))
        let center = CGPoint(x: point.x + unit * 0.15 * (1 - approach), y: point.y)
        let impact = sin(min(1, max(0, (phase - 0.20) / 0.20)) * .pi)
        var images = [placed(.paw, width: unit * (0.22 + 0.02 * impact), at: center,
                             angle: sin(phase * .pi * 4) * 0.10)]
        for index in 0..<3 {
            let delay = Double(index) * 0.10 + 0.22
            let amount = min(1, max(0, (progress - delay) / 0.60))
            guard amount > 0 else { continue }
            images.append(placed(.pawPrint, width: unit * 0.052,
                                 at: CGPoint(x: point.x + unit * (0.12 + CGFloat(index) * 0.06),
                                             y: point.y - unit * (0.05 + CGFloat(index) * 0.04)),
                                 angle: CGFloat(index) * 0.25 - 0.35, opacity: (1 - amount) * 0.8))
        }
        return front(merged(images))
    }
}
