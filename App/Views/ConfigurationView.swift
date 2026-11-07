import SwiftUI
import UniformTypeIdentifiers

enum SettingsCategory: String, CaseIterable, Identifiable {
    case camera, output, gestures, recognition, models, backgrounds

    var id: String { rawValue }
    var title: String {
        switch self {
        case .camera: "Kamera"
        case .output: "Ausgabe"
        case .gestures: "Gesten"
        case .recognition: "Bilderkennung"
        case .models: "Modelle"
        case .backgrounds: "Hintergründe"
        }
    }
    var symbol: String {
        switch self {
        case .camera: "camera.fill"
        case .output: "video.fill"
        case .gestures: "hand.wave.fill"
        case .recognition: "person.crop.rectangle"
        case .models: "square.stack.3d.up.fill"
        case .backgrounds: "photo.on.rectangle.angled"
        }
    }
    var color: Color {
        switch self {
        case .camera: .gray
        case .output: .blue
        case .gestures: .pink
        case .recognition: .purple
        case .models: .orange
        case .backgrounds: .green
        }
    }
    var subtitle: String {
        switch self {
        case .camera: "Wähle die Kamera für dein Livebild."
        case .output: "Bildformat und virtuelle Kamera für deine Video-Apps."
        case .gestures: "Wähle für jede Handgeste eine passende Reaction."
        case .recognition: "Passe Erkennung und Masken für jedes Modell an."
        case .models: "Verwalte lokale Modelle für die Bilderkennung."
        case .backgrounds: "Profile und Verbindung für die Hintergrundgenerierung."
        }
    }
}

struct ConfigurationView: View {
    @ObservedObject var settings: SegmentationSettingsModel
    @ObservedObject var camera: CameraModel
    @ObservedObject var extensionManager: ExtensionManager
    @ObservedObject var backgrounds: BackgroundModel
    @AppStorage("settingsCategory") private var selectedCategory = SettingsCategory.camera.rawValue
    @State private var choosingModel = false
    @State private var editingProfile: BackgroundProfile?
    @State private var confirmingDelete = false

    private var category: SettingsCategory { SettingsCategory(rawValue: selectedCategory) ?? .camera }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section {
                    ForEach(SettingsCategory.allCases) { category in
                        HStack(spacing: 10) {
                            categoryIcon(category, size: 28)
                            Text(category.title)
                        }
                        .padding(.vertical, 3)
                        .tag(category.rawValue)
                    }
                } header: {
                    Text("BetterCam").font(.headline).textCase(nil).padding(.vertical, 8)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    categoryIcon(category, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title).font(.title2.bold())
                        Text(category.subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 8)

                Form {
                    switch category {
                    case .camera: cameraSections
                    case .output: outputSections
                    case .gestures: GestureSettingsSections(camera: camera)
                    case .recognition: recognitionSections
                    case .models: modelSections
                    case .backgrounds: backgroundSections
                    }
                }
                .formStyle(.grouped)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(category.title)
        }
        .frame(minWidth: 840, idealWidth: 900, minHeight: 640, idealHeight: 740)
        .fileImporter(isPresented: $choosingModel, allowedContentTypes: [.item, .folder]) { result in
            switch result {
            case .success(let url): Task { await settings.importModel(url) }
            case .failure(let error): settings.reportImportError(error)
            }
        }
        .sheet(item: $editingProfile) { profile in
            BackgroundProfileEditor(profile: profile) { draft, imports in
                try backgrounds.save(draft, imports: imports)
            }
        }
        .confirmationDialog("Profil „\(backgrounds.selectedProfile?.name ?? "")“ löschen?", isPresented: $confirmingDelete) {
            Button("Profil löschen", role: .destructive) { backgrounds.deleteSelectedProfile() }
        } message: {
            Text("Der Pre-Prompt und die gespeicherten Referenzbilder werden entfernt.")
        }
        .task { camera.refreshCameras() }
        .onChange(of: settings.configuration) { _, configuration in
            camera.setSegmentationConfiguration(configuration)
        }
    }

    private func categoryIcon(_ category: SettingsCategory, size: CGFloat) -> some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.52, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.23))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var cameraSections: some View {
        Section {
            Picker("Kameraquelle", selection: $camera.selectedCameraID) {
                if camera.cameras.isEmpty { Text("Keine Kamera gefunden").tag("") }
                ForEach(camera.cameras) { Text($0.name).tag($0.id) }
            }
            .disabled(camera.isRunning || camera.isBusy)
            Button("Kameras aktualisieren", systemImage: "arrow.clockwise") { camera.refreshCameras() }
                .disabled(camera.isBusy)
        } header: {
            Text("Videoquelle")
        } footer: {
            Text("Stoppe die Kamera im Hauptfenster, um die Quelle zu wechseln. Deine Auswahl wird gespeichert.")
        }
        Section("Aktuelle Sitzung") {
            LabeledContent("Status", value: camera.isRunning ? "Kamera läuft" : "Gestoppt")
            LabeledContent("Eingangsauflösung", value: camera.isRunning ? camera.inputResolution : "–")
            LabeledContent("Verarbeitung", value: camera.isRunning ? "\(camera.framesPerSecond) FPS" : "–")
        }
        if let error = camera.error {
            Section {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private var outputSections: some View {
        Section {
            Picker("Auflösung", selection: $camera.outputConfiguration.resolution) {
                ForEach(OutputResolution.allCases) { resolution in
                    Text(resolution.title).tag(resolution)
                }
            }
            Picker("Bildrate", selection: $camera.outputConfiguration.frameRate) {
                ForEach(OutputConfiguration.frameRates, id: \.self) { rate in
                    Text("\(rate) FPS").tag(rate)
                }
            }
        } header: {
            Text("Videoformat")
        } footer: {
            Text("Gilt für die Vorschau und den Ausgang „BetterCam“. Stoppe die Kamera, um das Format zu ändern. Die erreichbare Bildrate hängt von Kamera, Modell und Mac ab.")
        }
        .disabled(camera.isRunning || camera.isBusy)

        Section("Virtuelle Kamera") {
            LabeledContent("Name in Video-Apps", value: "BetterCam")
            LabeledContent("Gewähltes Format", value: camera.outputConfiguration.summary)
            Label(extensionManager.status, systemImage: "puzzlepiece.extension")
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("Virtuelle Kamera aktivieren") { extensionManager.activate() }
                    .disabled(extensionManager.isBusy)
                if extensionManager.isBusy { ProgressView().controlSize(.small) }
            }
            Text("Wähle anschließend „BetterCam“ als Kamera in deiner Video-App. Bei einem Formatwechsel muss die Video-App die Kamera gegebenenfalls neu öffnen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var recognitionSections: some View {
        Section {
            modelPicker
            Text(settings.configuration.provider == .apple
                 ? "Apples Personenmodell verarbeitet deine Kamera lokal auf dem Mac."
                 : "Das gewählte Modell liefert die Vordergrundmaske. Die Verarbeitung bleibt lokal auf dem Mac.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Modelle verwalten …") { selectedCategory = SettingsCategory.models.rawValue }
        } header: {
            Text("Aktives Modell")
        } footer: {
            Text("Die Auswahl und die Parameter werden gespeichert. Die Erkennung greift, sobald du einen Hintergrund verwendest.")
        }

        RecognitionControls(settings: settings)
        CustomMaskControls(settings: settings)

        if settings.configuration.provider == .apple {
            Section("Zubehör") {
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
        Section("Maskenvorschau") {
            Toggle("Maske nur in Vorschau anzeigen", isOn: $camera.previewMask)
            Text("Bei aktiver Hintergrundersetzung: Weiß bleibt erhalten, Schwarz wird ersetzt, Grau ist durchsichtig. Die virtuelle Kamera erhält weiterhin das gefilterte Farbbild.")
                .font(.caption).foregroundStyle(.secondary)
        }
        modelError
    }

    private var modelPicker: some View {
        Picker("Modell", selection: selectedModel) {
            Text("Apple Vision").tag("apple")
            ForEach(SegmentationModelCatalog.models) { Text($0.title).tag($0.id) }
            ForEach(settings.installedModels.filter { $0.catalogID == nil }) { Text($0.name).tag($0.id) }
            Text("Eigenes Modell importieren …").tag("import")
        }
        .disabled(settings.isBusy)
    }

    @ViewBuilder private var modelSections: some View {
        Section("Auswahl") { modelPicker }
        ModelCatalogSection(settings: settings)
        Section("Eigene Core-ML-Modelle") {
            LabeledContent("Zuletzt gewähltes eigenes Modell", value: settings.configuration.customModelName ?? "Keines")
            Button("Modell importieren …", systemImage: "square.and.arrow.down") { choosingModel = true }
                .disabled(settings.isBusy)
            if settings.isImporting && settings.downloadingModelID == nil {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Modell wird geprüft …").foregroundStyle(.secondary)
                }
            }
            Text("Importiere ein Core-ML-Modell als .mlmodel, .mlpackage oder .mlmodelc.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Unterstützte Modelle") {
                Text("Ein Bildeingang und eine einzelne Graustufen-Vordergrundmaske oder ein einkanaliges Array mit Werten von 0 bis 1. Weiß bedeutet behalten, Schwarz bedeutet Hintergrund. Die U²-Net-Modellfamilie wird ebenfalls unterstützt. Modelle mit mehreren Klassen oder zusätzlichen Zustandseingängen benötigen einen eigenen Adapter.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        modelError
    }

    @ViewBuilder private var modelError: some View {
        if let error = settings.error {
            Section {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private var backgroundSections: some View {
        Section {
            Picker("Profil", selection: $backgrounds.selectedProfileID) {
                Text("Profil auswählen").tag(UUID?.none)
                ForEach(backgrounds.profiles) { Text($0.name).tag(Optional($0.id)) }
            }
            if let profile = backgrounds.selectedProfile {
                LabeledContent("Referenzbilder", value: "\(profile.assets.count)")
                if !profile.prePrompt.isEmpty {
                    Text(profile.prePrompt).font(.callout).foregroundStyle(.secondary).lineLimit(4)
                }
            }
            HStack {
                Button("Neues Profil …", systemImage: "plus") { editingProfile = BackgroundProfile() }
                Button("Bearbeiten …") { editingProfile = backgrounds.selectedProfile }
                    .disabled(backgrounds.selectedProfile == nil)
                Spacer()
                Button("Löschen …", role: .destructive) { confirmingDelete = true }
                    .disabled(backgrounds.selectedProfile == nil)
            }
        } header: {
            Text("Generierungsprofile")
        } footer: {
            Text("Profile speichern feste Vorgaben und Referenzbilder. Einen Hintergrund erzeugst du über „Hintergrund erzeugen“ im Hauptfenster.")
        }
        .disabled(backgrounds.isGenerating)

        Section("Verbindung") {
            Toggle("Codex automatisch bei Bedarf starten", isOn: $backgrounds.automaticallyStartServer)
            if backgrounds.automaticallyStartServer {
                Text("BetterCam startet Codex beim Generieren und beendet den Prozess anschließend. Codex muss installiert und angemeldet sein.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Server-Adresse", text: $backgrounds.serverAddress)
                    .textFieldStyle(.roundedBorder)
                Text("Verwende die Adresse deines lokalen Codex App Servers.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(backgrounds.isGenerating)
        if let error = backgrounds.error {
            Section {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).textSelection(.enabled)
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
