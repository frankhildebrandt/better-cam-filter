import ImageIO
import SwiftUI

struct BackgroundLibraryView: View {
    @ObservedObject var model: BackgroundModel
    @ObservedObject var camera: CameraModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Mediathek", systemImage: "photo.on.rectangle.angled").font(.title2.bold())
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Wähle ein Bild, um es als Kamerahintergrund zu verwenden.")
                .foregroundStyle(.secondary)
            if let error = model.libraryError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            if model.library.isEmpty {
                ContentUnavailableView("Noch keine Bilder", systemImage: "photo.on.rectangle", description:
                    Text("Erzeugte Hintergründe werden hier automatisch gespeichert und bleiben nach einem Neustart verfügbar."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                        ForEach(model.library) { entry in
                            libraryButton(entry)
                        }
                    }.padding(4)
                }
            }
        }
        .padding(24).frame(width: 720, height: 560)
    }

    private func libraryButton(_ entry: GeneratedBackground) -> some View {
        let isActive = camera.backgroundLibraryID == entry.id && camera.backgroundEnabled
        return Button { model.select(entry, camera: camera) } label: {
            VStack(alignment: .leading, spacing: 8) {
                BackgroundThumbnail(url: model.imageURL(entry))
                    .overlay(alignment: .bottomTrailing) {
                        if isActive {
                            Label("Aktiv", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold)).padding(6)
                                .background(.regularMaterial, in: Capsule()).padding(6)
                        }
                    }
                Text(entry.name).font(.callout.weight(.medium)).lineLimit(2)
                Text(entry.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help("„\(entry.name)“ als Hintergrund verwenden")
        .accessibilityValue(isActive ? "Aktiver Hintergrund" : "")
    }
}

private struct BackgroundThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .frame(height: 112).clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            // Downsample previews so browsing does not retain every full-resolution image.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
            ]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            image = NSImage(cgImage: thumbnail, size: .zero)
        }
    }
}
