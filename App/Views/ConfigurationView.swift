import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationView: View {
    @ObservedObject var settings: SegmentationSettingsModel
    @ObservedObject var camera: CameraModel
    @State private var choosingModel = false

    var body: some View {
        Form {
            Section {
                Picker("Modell", selection: selectedModel) {
                    Text("Apple Vision").tag("apple")
                    ForEach(SegmentationModelCatalog.models) { Text($0.title).tag($0.id) }
                    ForEach(settings.installedModels.filter { $0.catalogID == nil }) { Text($0.name).tag($0.id) }
                    Text("Eigenes Modell importieren …").tag("import")
                }
                .disabled(settings.isBusy)
                Text(settings.configuration.provider == .apple
                     ? "Apples Personenmodell verarbeitet deine Kamera lokal auf dem Mac."
                     : "Das gewählte Modell liefert die Vordergrundmaske. Die Verarbeitung bleibt lokal auf dem Mac.")
                    .font(.callout).foregroundStyle(.secondary)
            } header: {
                Label("Bilderkennung", systemImage: "person.crop.rectangle")
            } footer: {
                Text("Die Modellauswahl wird gespeichert und gilt für Vorschau und virtuelle Kamera.")
            }

            if settings.configuration.provider == .custom {
                CustomMaskControls(settings: settings)
            }

            Section("Maskenvorschau") {
                Toggle("Maske nur in Vorschau anzeigen", isOn: $camera.previewMask)
                    .disabled(!camera.backgroundEnabled)
                Text("Weiß bleibt erhalten, Schwarz wird ersetzt. Graue Bereiche sind durchsichtig. Die virtuelle Kamera erhält weiterhin das gefilterte Farbbild.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ModelCatalogSection(settings: settings)

            Section("Custom-Modell") {
                LabeledContent("Importiertes Modell", value: settings.configuration.customModelName ?? "Keines")
                Button("Modell importieren …", systemImage: "square.and.arrow.down") { choosingModel = true }
                    .disabled(settings.isBusy)
                if settings.isImporting && settings.downloadingModelID == nil {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Modell wird geprüft …").foregroundStyle(.secondary)
                    }
                }
                Text("Alternativ ein eigenes Core-ML-Modell als .mlmodel, .mlpackage oder .mlmodelc importieren.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Unterstützte Modelle") {
                    Text("Ein Bildeingang und eine einzelne Graustufen-Vordergrundmaske oder ein einkanaliges Array mit Werten von 0 bis 1. Weiß bedeutet behalten, Schwarz bedeutet Hintergrund. Die U²-Net-Modellfamilie wird ebenfalls unterstützt. Andere Modelle mit mehreren Klassen oder zusätzlichen Zustandseingängen benötigen einen eigenen Adapter.")
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
        .frame(width: 580, height: 680)
        .navigationTitle("Konfiguration")
        .fileImporter(isPresented: $choosingModel, allowedContentTypes: [.item, .folder]) { result in
            switch result {
            case .success(let url): Task { await settings.importModel(url) }
            case .failure(let error): settings.reportImportError(error)
            }
        }
    }

    private var selectedModel: Binding<String> {
        Binding(get: {
            guard settings.configuration.provider == .custom else { return "apple" }
            let installed = settings.installedModels.first { $0.modelURL == settings.configuration.customModelURL }
            return installed?.catalogID ?? installed?.id ?? "import"
        }, set: { selected in
            if selected == "apple" { settings.select(.apple) }
            else if selected == "import" { choosingModel = true }
            else if let model = SegmentationModelCatalog.models.first(where: { $0.id == selected }) { settings.use(model) }
            else if let model = settings.installedModels.first(where: { $0.id == selected }) { settings.select(model) }
        })
    }
}
