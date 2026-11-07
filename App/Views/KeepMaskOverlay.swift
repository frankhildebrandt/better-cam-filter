import SwiftUI

struct KeepMaskOverlay: View {
    @ObservedObject var camera: CameraModel
    @State private var activeStroke: KeepStroke?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for stroke in camera.keepStrokes + (activeStroke.map { [$0] } ?? []) {
                    guard let first = stroke.points.first else { continue }
                    let radius = stroke.radius * size.width
                    let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
                    var path = Path()
                    path.move(to: start)
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    context.stroke(path, with: .color(.cyan.opacity(0.4)),
                                   style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, lineJoin: .round))
                    if stroke.points.count == 1 {
                        context.fill(Path(ellipseIn: CGRect(x: start.x - radius, y: start.y - radius,
                                                           width: radius * 2, height: radius * 2)),
                                     with: .color(.cyan.opacity(0.4)))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { event in
                    let point = CGPoint(x: min(1, max(0, event.location.x / geometry.size.width)),
                                        y: min(1, max(0, event.location.y / geometry.size.height)))
                    if activeStroke == nil { activeStroke = KeepStroke(points: [], radius: camera.brushRadius) }
                    if let previous = activeStroke?.points.last,
                       hypot(previous.x - point.x, previous.y - point.y) < 0.002 { return }
                    activeStroke?.points.append(point)
                }
                .onEnded { _ in
                    if let activeStroke { camera.addKeepStroke(activeStroke) }
                    activeStroke = nil
                })
            .accessibilityLabel("Schutzbereiche auf das Originalbild malen")
        }
    }
}
