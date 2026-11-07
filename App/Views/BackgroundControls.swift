import SwiftUI

struct BackgroundControls: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var backgrounds: BackgroundModel
    @Binding var choosingBackground: Bool
    @Binding var showingGenerator: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HINTERGRUND").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Toggle("Durch Bild ersetzen", isOn: $camera.backgroundEnabled)
                .disabled(camera.backgroundName == nil)
            Button("Bild auswählen …", systemImage: "photo") { choosingBackground = true }
            Button("Hintergrund erzeugen …", systemImage: "sparkles") { showingGenerator = true }
            if backgrounds.isGenerating {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(backgrounds.status).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let name = camera.backgroundName {
                Text(name).font(.caption).lineLimit(2).foregroundStyle(.secondary)
            }
            Picker("Erkennung", selection: $camera.segmentationMode) {
                ForEach(SegmentationMode.allCases) { Text($0.title).tag($0) }
            }
            Text("Personenmaske mit gezielter Zubehör-Ergänzung. Verarbeitung lokal auf deinem Mac.")
                .font(.caption).foregroundStyle(.secondary)
            if camera.segmentationMode == .foregroundObjects {
                Toggle("Stuhl & Mikrofon ergänzen", isOn: $camera.accessoriesEnabled)
                Text("Zubehör wird zeitlich bestätigt. Bei dunklem Raumhintergrund ausschalten.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Bereiche behalten", isOn: $camera.isEditingKeepMask)
                .disabled(!camera.isRunning || !camera.backgroundEnabled)
            if camera.isEditingKeepMask {
                Text("Mikrofon oder Stuhl im Originalbild übermalen. Innerhalb der Markierung bleibt alles sichtbar, auch Raumhintergrund.")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(value: $camera.brushRadius, in: 0.005...0.065) { Text("Pinselgröße") }
                HStack {
                    Button("Rückgängig", systemImage: "arrow.uturn.backward") { camera.undoKeepStroke() }
                    Button("Löschen", systemImage: "trash") { camera.clearKeepStrokes() }
                }
                .disabled(camera.keepStrokes.isEmpty)
            } else if !camera.keepStrokes.isEmpty {
                Text("\(camera.keepStrokes.count) Schutzmarkierungen aktiv")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
