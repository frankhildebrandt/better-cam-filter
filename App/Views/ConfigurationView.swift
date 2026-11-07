import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationView: View {
    @ObservedObject var settings: SegmentationSettingsModel
    @ObservedObject var camera: CameraModel
    @State private var choosingModel = false

    var body: some View {
        Form {
            Section {
                Picker("Modell", selection: provider) {
                    ForEach(SegmentationProvider.allCases) { Text($0.title).tag($0) }
                }
                .disabled(settings.isImporting)
                Text(settings.configuration.provider == .apple
                     ? "Apples Personenmodell verarbeitet deine Kamera lokal auf dem Mac."
                     : "Dein importiertes Modell liefert die Vordergrundmaske. Die Verarbeitung bleibt lokal auf dem Mac.")
                    .font(.callout).foregroundStyle(.secondary)
            } header: {
                Label("Bilderkennung", systemImage: "person.crop.rectangle")
            } footer: {
                Text("Die Modellauswahl wird gespeichert und gilt für Vorschau und virtuelle Kamera.")
            }

            Section("Custom-Modell") {
                LabeledContent("Importiertes Modell", value: settings.configuration.customModelName ?? "Keines")
                Button("Modell importieren …", systemImage: "square.and.arrow.down") { choosingModel = true }
                    .disabled(settings.isImporting)
                if settings.isImporting {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Modell wird geprüft …").foregroundStyle(.secondary)
                    }
                }
                Text("Core ML: .mlmodel, .mlpackage oder .mlmodelc. Ein geeignetes Modell muss separat importiert werden.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Unterstützte Modelle") {
                    Text("Ein Bildeingang und eine einzelne Graustufen-Vordergrundmaske oder ein einkanaliges Array mit Werten von 0 bis 1. Weiß bedeutet behalten, Schwarz bedeutet Hintergrund. Modelle mit mehreren Klassen oder zusätzlichen Zustandseingängen benötigen einen eigenen Adapter.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if settings.configuration.provider == .apple {
                Section("Apple-Maske ergänzen") {
                    Picker("Erkennung", selection: $camera.segmentationMode) {
                        ForEach(SegmentationMode.allCases) { Text($0.title).tag($0) }
                    }
                    if camera.segmentationMode == .foregroundObjects {
                        Toggle("Stuhl & Mikrofon ergänzen", isOn: $camera.accessoriesEnabled)
                        Text("Ergänzt Zubehör nahe der Person anhand von Farbe und Bewegung. Bei dunklem Raumhintergrund ausschalten.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let error = settings.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 570)
        .navigationTitle("Konfiguration")
        .fileImporter(isPresented: $choosingModel, allowedContentTypes: [.item, .folder]) { result in
            switch result {
            case .success(let url): Task { await settings.importModel(url) }
            case .failure(let error): settings.reportImportError(error)
            }
        }
    }

    private var provider: Binding<SegmentationProvider> {
        Binding(get: { settings.configuration.provider }, set: { selected in
            if selected == .custom && settings.configuration.customModelURL == nil { choosingModel = true }
            else { settings.select(selected) }
        })
    }
}
