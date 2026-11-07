import CoreGraphics

extension ReactionDrawing {
    func bunnyHead() {
        ellipse(CGRect(x: 38, y: 31, width: 180, height: 163), cream)
        ellipse(CGRect(x: 26, y: 43, width: 62, height: 71), cream)
        ellipse(CGRect(x: 168, y: 43, width: 62, height: 71), cream)
        face(at: CGPoint(x: 128, y: 109), spread: 28)
        ellipse(CGRect(x: 122, y: 97, width: 12, height: 8), pink)
        ellipse(CGRect(x: 49, y: 24, width: 48, height: 28), cream)
        ellipse(CGRect(x: 159, y: 24, width: 48, height: 28), cream)
    }

    func bunnyEar() {
        ellipse(CGRect(x: 83, y: 18, width: 90, height: 221), cream)
        ellipse(CGRect(x: 105, y: 58, width: 46, height: 155), pink.copy(alpha: 0.8) ?? pink)
    }

    func bean() {
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: 66, y: 46))
        shape.addCurve(to: CGPoint(x: 187, y: 208), control1: CGPoint(x: 0, y: 145), control2: CGPoint(x: 100, y: 269))
        shape.addCurve(to: CGPoint(x: 172, y: 97), control1: CGPoint(x: 223, y: 180), control2: CGPoint(x: 145, y: 145))
        shape.addCurve(to: CGPoint(x: 66, y: 46), control1: CGPoint(x: 229, y: 30), control2: CGPoint(x: 123, y: -10))
        shape.closeSubpath()
        path(shape, fill: CGColor(srgbRed: 0.81, green: 0.89, blue: 0.66, alpha: 1), outline: true)
        face(at: CGPoint(x: 118, y: 129), spread: 24)
        ellipse(CGRect(x: 41, y: 81, width: 26, height: 50), cream)
        ellipse(CGRect(x: 179, y: 93, width: 24, height: 49), cream)
        ellipse(CGRect(x: 77, y: 22, width: 38, height: 21), ink)
        ellipse(CGRect(x: 141, y: 24, width: 38, height: 21), ink)
    }

    func paw() {
        let coat = CGColor(srgbRed: 0.98, green: 0.88, blue: 0.75, alpha: 1)
        ellipse(CGRect(x: 48, y: 25, width: 160, height: 158), coat)
        ellipse(CGRect(x: 24, y: 117, width: 53, height: 80), coat)
        ellipse(CGRect(x: 71, y: 161, width: 54, height: 74), coat)
        ellipse(CGRect(x: 127, y: 163, width: 54, height: 72), coat)
        ellipse(CGRect(x: 180, y: 121, width: 52, height: 77), coat)
        ellipse(CGRect(x: 39, y: 139, width: 27, height: 40), pink)
        ellipse(CGRect(x: 84, y: 181, width: 28, height: 36), pink)
        ellipse(CGRect(x: 140, y: 183, width: 28, height: 35), pink)
        ellipse(CGRect(x: 191, y: 141, width: 27, height: 39), pink)
        ellipse(CGRect(x: 83, y: 58, width: 91, height: 77), pink)
        ellipse(CGRect(x: 77, y: 55, width: 45, height: 44), pink)
        ellipse(CGRect(x: 139, y: 55, width: 45, height: 44), pink)
    }

    func pawPrint() {
        ellipse(CGRect(x: 71, y: 37, width: 114, height: 106), pink)
        for (x, y) in [(35.0, 134.0), (86.0, 173.0), (143.0, 173.0), (190.0, 134.0)] {
            ellipse(CGRect(x: x, y: y, width: 34, height: 47), pink)
        }
    }

    func cloud() {
        let white = CGColor(srgbRed: 1, green: 0.98, blue: 0.96, alpha: 1)
        context.setFillColor(white)
        context.fill(CGRect(x: 47, y: 66, width: 164, height: 72))
        ellipse(CGRect(x: 19, y: 64, width: 89, height: 90), white)
        ellipse(CGRect(x: 68, y: 94, width: 102, height: 102), white)
        ellipse(CGRect(x: 130, y: 83, width: 88, height: 90), white)
        ellipse(CGRect(x: 161, y: 63, width: 77, height: 78), white)
        face(at: CGPoint(x: 128, y: 106), spread: 23)
    }

    func rainbow() {
        let colors: [CGColor] = [
            CGColor(srgbRed: 1, green: 0.65, blue: 0.72, alpha: 1),
            CGColor(srgbRed: 1, green: 0.79, blue: 0.58, alpha: 1),
            CGColor(srgbRed: 1, green: 0.91, blue: 0.57, alpha: 1),
            CGColor(srgbRed: 0.69, green: 0.86, blue: 0.71, alpha: 1),
            CGColor(srgbRed: 0.65, green: 0.80, blue: 0.97, alpha: 1),
            CGColor(srgbRed: 0.80, green: 0.73, blue: 0.93, alpha: 1)
        ]
        context.setLineWidth(11)
        context.setLineCap(.butt)
        for (index, color) in colors.enumerated() {
            context.setStrokeColor(color)
            context.addArc(center: CGPoint(x: 128, y: 39), radius: 117 - CGFloat(index) * 11,
                           startAngle: 0, endAngle: .pi, clockwise: false)
            context.strokePath()
        }
    }
}
