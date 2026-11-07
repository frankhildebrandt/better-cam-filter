import SwiftUI

struct ModelCatalogSection: View {
    @ObservedObject var settings: SegmentationSettingsModel

    var body: some View {
        Section {
            ForEach(SegmentationModelCatalog.models) { model in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(model.title).font(.headline)
                        if model.id == SegmentationModelCatalog.recommendedID {
                            Text("Empfehlung").font(.caption.weight(.medium)).foregroundStyle(.tint)
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: model.byteCount, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                    Text(model.summary).font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Link("Quelle & Modellinfos", destination: model.sourceURL)
                        Spacer()
                        Text(model.license).foregroundStyle(.secondary)
                    }.font(.caption)
                    if settings.downloadingModelID == model.id {
                        ProgressView(value: settings.downloadProgress)
                        HStack {
                            Text(settings.isImporting ? "Modell wird vorbereitet …"
                                 : "Download: \(Int(settings.downloadProgress * 100)) %")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Abbrechen") { settings.cancelDownload() }.disabled(settings.isImporting)
                        }
                    } else {
                        let installed = settings.installedModels.first { $0.catalogID == model.id }
                        if settings.configuration.provider == .custom,
                           let installed, settings.configuration.customModelURL == installed.modelURL {
                            Label("Aktiv", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button(installed == nil ? "Herunterladen und verwenden" : "Verwenden") { settings.use(model) }
                                .disabled(settings.isBusy)
                        }
                    }
                }.padding(.vertical, 6)
            }
        } header: {
            Text("Modelle herunterladen")
        } footer: {
            Text("Die Modelle wählen Vordergrundobjekte automatisch. Mikrofon und Stuhl können je nach Bild fehlen. Nur der Modelldownload benötigt Internet; deine Kamerabilder bleiben lokal.")
        }
    }
}
