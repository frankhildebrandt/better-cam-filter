import CoreImage
import Foundation

extension ReactionScene {
    func love() -> ReactionLayers {
        let pulse = 1 + 0.06 * sin(phase * .pi * 8)
        var images = [placed(.heart, width: unit * 0.18 * pulse, at: point)]
        for index in 0..<6 {
            let life = (phase + CGFloat(index) / 6).truncatingRemainder(dividingBy: 1)
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let x = point.x + side * unit * (0.06 + life * 0.13)
            let y = point.y + life * unit * 0.30
            images.append(placed(.heart, width: unit * (0.036 + CGFloat(index % 3) * 0.008),
                                 at: CGPoint(x: x, y: y), angle: side * 0.25,
                                 opacity: Double(sin(life * .pi)) * 0.85))
        }
        return front(merged(images))
    }

    func rainbow() -> ReactionLayers {
        let growth = CGFloat(smooth(progress / 0.25))
        let width = min(bounds.width * 0.86, unit * 1.45) * (0.88 + growth * 0.12)
        let center = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.52)
        let cloudOffset = width * 0.405
        let cloudY = center.y - width * 0.215
        let background = merged([
            placed(.rainbow, width: width, at: center),
            placed(.cloud, width: unit * 0.22,
                   at: CGPoint(x: center.x - cloudOffset, y: cloudY + sin(phase * .pi * 3) * unit * 0.008)),
            placed(.cloud, width: unit * 0.22,
                   at: CGPoint(x: center.x + cloudOffset, y: cloudY - sin(phase * .pi * 3) * unit * 0.008))
        ])
        var confetti: [CIImage] = []
        for index in 0..<14 {
            let fraction = CGFloat(index) / 13
            let fall = (phase * 0.8 + CGFloat(index % 5) * 0.17).truncatingRemainder(dividingBy: 1)
            let x = bounds.minX + bounds.width * (0.07 + fraction * 0.86)
            // Keep the middle of the frame clear of particles around the speaker's face.
            guard fraction < 0.34 || fraction > 0.66 else { continue }
            let y = bounds.maxY - bounds.height * fall
            let star = placed(.star, width: unit * (0.018 + CGFloat(index % 3) * 0.006),
                              at: CGPoint(x: x + sin(phase * 7 + CGFloat(index)) * unit * 0.025, y: y),
                              angle: phase * 3 + CGFloat(index), opacity: 0.85)
            confetti.append(star)
        }
        return ReactionLayers(foreground: merged(confetti), background: background)
    }

    func tinyLove() -> ReactionLayers {
        let flight = CGFloat(smooth(max(0, (progress - 0.36) / 0.64)))
        let target = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.80)
        let center = CGPoint(x: point.x + (target.x - point.x) * flight * 0.45,
                             y: point.y + (target.y - point.y) * flight)
        let pulse = 1 + 0.12 * sin(min(phase, 0.5) * .pi * 8)
        let width = unit * 0.09 * pulse * (1 + flight * 0.9)
        let heart = placed(.heart, width: width, at: center, angle: sin(phase * .pi * 4) * 0.12)
        let trail = placed(.star, width: unit * 0.025,
                           at: CGPoint(x: center.x - unit * 0.04, y: center.y - flight * unit * 0.09),
                           angle: phase * 2, opacity: Double(flight) * 0.7)
        return front(merged([trail, heart]))
    }
}
