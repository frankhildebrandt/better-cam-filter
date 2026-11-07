import SwiftUI

struct BackgroundControls: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var backgrounds: BackgroundModel
    @Binding var choosingBackground: Bool
    @Binding var showingGenerator: Bool
    @Binding var showingLibrary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Hintergrund").font(.headline)
                    Spacer()
                    Toggle("Hintergrund ersetzen", isOn: $camera.backgroundEnabled)
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(camera.backgroundName == nil)
                }
                if let name = camera.backgroundName {
                    Text(name).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                }
                libraryPreviews
                HStack {
                    Button("Importieren …", systemImage: "plus") { choosingBackground = true }
                    Spacer(minLength: 4)
                    Button("Alle Bilder …") { showingLibrary = true }
                        .disabled(backgrounds.library.isEmpty)
                }
                .controlSize(.small)
            }
            Button { showingGenerator = true } label: {
                Label("Hintergrund erzeugen …", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
            }
            if backgrounds.isGenerating {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(backgrounds.status).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = backgrounds.libraryError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
            }
            Divider()
            keepMaskControls
        }
    }

    @ViewBuilder
    private var libraryPreviews: some View {
        if backgrounds.library.isEmpty {
            Button { choosingBackground = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus").font(.title2)
                    Text("Dein nächster Hintergrund")
                        .font(.caption.weight(.medium))
                    Text("Bild importieren oder erzeugen")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hintergrundbild importieren")
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 10) {
                ForEach(backgrounds.library.prefix(8)) { entry in
                    thumbnailButton(entry)
                }
            }
        }
    }

    private func thumbnailButton(_ entry: GeneratedBackground) -> some View {
        let isActive = camera.backgroundLibraryID == entry.id && camera.backgroundEnabled
        return Button { backgrounds.select(entry, camera: camera) } label: {
            VStack(alignment: .leading, spacing: 5) {
                BackgroundThumbnail(url: backgrounds.imageURL(entry), height: 68)
                    .overlay(alignment: .bottomTrailing) {
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .font(.body).padding(5)
                                .shadow(color: .black.opacity(0.2), radius: 2)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 2))
                Text(entry.name).font(.caption2).lineLimit(1)
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help("„\(entry.name)“ als Hintergrund verwenden")
        .accessibilityLabel(entry.name)
        .accessibilityValue(isActive ? "Aktiver Hintergrund" : "")
    }

    private var keepMaskControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                camera.isEditingKeepMask.toggle()
            } label: {
                Label(camera.isEditingKeepMask ? "Markieren beenden" : "Bereiche behalten …",
                      systemImage: camera.isEditingKeepMask ? "checkmark" : "paintbrush.pointed")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!camera.isRunning || !camera.backgroundEnabled)
            if camera.isEditingKeepMask {
                Text("Übermale Mikrofon oder Stuhl im Originalbild, um diese Bereiche zu behalten.")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pinselgröße").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $camera.brushRadius, in: 0.005...0.065) { Text("Pinselgröße") }
                }
                HStack {
                    Button("Rückgängig", systemImage: "arrow.uturn.backward") { camera.undoKeepStroke() }
                    Button("Löschen", systemImage: "trash") { camera.clearKeepStrokes() }
                }
                .controlSize(.small)
                .disabled(camera.keepStrokes.isEmpty)
            } else if !camera.keepStrokes.isEmpty {
                Text("\(camera.keepStrokes.count) Schutzmarkierungen aktiv")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
