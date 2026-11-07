import SwiftUI

struct BackgroundGeneratorView: View {
    @ObservedObject var model: BackgroundModel
    @ObservedObject var camera: CameraModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingProfile: BackgroundProfile?
    @State private var confirmingDelete = false
    @State private var showingConnection = false
    @State private var showingLibrary = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Hintergrund erzeugen", systemImage: "sparkles").font(.title2.bold())
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Wähle ein Profil und ergänze den Kontext für deinen nächsten Hintergrund.")
                .foregroundStyle(.secondary)
            HStack {
                Picker("Profil", selection: $model.selectedProfileID) {
                    Text("Profil auswählen").tag(UUID?.none)
                    ForEach(model.profiles) { Text($0.name).tag(Optional($0.id)) }
                }
                Button("Neu", systemImage: "plus") { editingProfile = BackgroundProfile() }
                Button { editingProfile = model.selectedProfile } label: { Image(systemName: "pencil") }
                    .help("Profil bearbeiten").disabled(model.selectedProfile == nil)
                Button(role: .destructive) { confirmingDelete = true } label: { Image(systemName: "trash") }
                    .help("Profil löschen").disabled(model.selectedProfile == nil)
            }
            .disabled(model.isGenerating)
            if let profile = model.selectedProfile {
                VStack(alignment: .leading, spacing: 6) {
                    if !profile.prePrompt.isEmpty {
                        Text(profile.prePrompt).lineLimit(3).textSelection(.enabled)
                    }
                    Label("\(profile.assets.count) feste Referenzbilder werden bei jeder Generierung verwendet.", systemImage: "photo.on.rectangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Lege ein Profil mit deinen festen Vorgaben und optionalen Referenzbildern an.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Zusätzlicher Kontext").font(.headline)
                TextField("Zum Beispiel: Abendlicht, Blick auf Berlin, dezente Pflanzen …", text: $model.context, axis: .vertical)
                    .lineLimit(4...7).textFieldStyle(.roundedBorder)
                    .disabled(model.isGenerating)
                Text("Optional. Pre-Prompt und Assets aus dem Profil sind immer dabei.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Codex App Server", isExpanded: $showingConnection) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Server-Adresse", text: $model.serverAddress).textFieldStyle(.roundedBorder)
                        .disabled(model.isGenerating)
                    Text("Starte den App Server auf diesem Mac mit angemeldetem Codex-Konto:")
                    Text("codex app-server --listen ws://127.0.0.1:4500")
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }.font(.caption).padding(.top, 8)
            }
            Text("Zur Generierung werden Pre-Prompt, Kontext und alle Profilbilder über Codex an OpenAI übertragen.")
                .font(.caption).foregroundStyle(.secondary)
            if let image = model.generatedImage {
                Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button("Mediathek öffnen …", systemImage: "photo.on.rectangle.angled") { showingLibrary = true }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            HStack {
                if model.isGenerating { ProgressView().controlSize(.small) }
                Text(model.status).font(.callout).foregroundStyle(.secondary)
                Spacer()
                if model.isGenerating {
                    Button("Abbrechen") { Task { await model.cancel() } }
                } else {
                    Button("Hintergrund erzeugen", systemImage: "sparkles") { model.generate(camera: camera) }
                        .buttonStyle(.borderedProminent).disabled(model.selectedProfile == nil)
                }
            }
        }
        .padding(24)
        }
        .frame(width: 640).frame(minHeight: 520, idealHeight: 680, maxHeight: 720)
        .sheet(item: $editingProfile) { profile in
            BackgroundProfileEditor(profile: profile) { draft, imports in try model.save(draft, imports: imports) }
        }
        .sheet(isPresented: $showingLibrary) {
            BackgroundLibraryView(model: model, camera: camera)
        }
        .confirmationDialog("Profil „\(model.selectedProfile?.name ?? "")“ löschen?", isPresented: $confirmingDelete) {
            Button("Profil löschen", role: .destructive) { model.deleteSelectedProfile() }
        } message: { Text("Der Pre-Prompt und die gespeicherten Referenzbilder werden entfernt.") }
    }
}

private struct BackgroundProfileEditor: View {
    @State var profile: BackgroundProfile
    var save: (BackgroundProfile, [BackgroundAssetImport]) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var imports: [BackgroundAssetImport] = []
    @State private var choosingAssets = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hintergrundprofil").font(.title2.bold())
            TextField("Profilname", text: $profile.name).textFieldStyle(.roundedBorder)
            Text("Pre-Prompt").font(.headline)
            Text("Diese Vorgaben gelten für jeden Hintergrund aus diesem Profil.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $profile.prePrompt).font(.body).padding(6)
                .frame(height: 140).background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            HStack {
                Text("Feste Referenzbilder").font(.headline)
                Spacer()
                Button("Bilder hinzufügen …", systemImage: "plus") { choosingAssets = true }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(profile.assets) { asset in
                        assetRow(asset.name) { profile.assets.removeAll { $0.id == asset.id } }
                    }
                    ForEach(imports.indices, id: \.self) { index in
                        assetRow(imports[index].name) { imports.remove(at: index) }
                    }
                    if profile.assets.isEmpty && imports.isEmpty {
                        Text("Optional: Logos, Stilvorlagen oder andere Referenzbilder.").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 110)
            if let error { Text(error).font(.callout).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Profil speichern") {
                    do { try save(profile, imports); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!profile.isValid)
            }
        }
        .padding(24).frame(width: 560)
        .fileImporter(isPresented: $choosingAssets, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            do { imports.append(contentsOf: try BackgroundModel.importAssets(result.get())); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }

    private func assetRow(_ name: String, remove: @escaping () -> Void) -> some View {
        HStack {
            Label(name, systemImage: "photo").lineLimit(1)
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }.buttonStyle(.plain).help("Bild entfernen")
        }
    }
}
