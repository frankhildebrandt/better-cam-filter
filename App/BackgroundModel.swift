import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class BackgroundModel: ObservableObject {
    @Published private(set) var profiles: [BackgroundProfile] = []
    @Published var selectedProfileID: UUID? {
        didSet { UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: "backgroundProfileID") }
    }
    @Published var context = ""
    @Published var serverAddress = UserDefaults.standard.string(forKey: "codexServerAddress") ?? "ws://127.0.0.1:4500" {
        didSet { UserDefaults.standard.set(serverAddress, forKey: "codexServerAddress") }
    }
    @Published private(set) var isGenerating = false
    @Published private(set) var status = ""
    @Published private(set) var error: String?
    @Published private(set) var generatedImage: NSImage?
    private let store = BackgroundProfileStore.applicationStore
    private let client = CodexBackgroundClient()
    private var generation: Task<Void, Never>?

    var selectedProfile: BackgroundProfile? { profiles.first { $0.id == selectedProfileID } }

    init() {
        do {
            profiles = try store.load()
            let saved = UserDefaults.standard.string(forKey: "backgroundProfileID").flatMap(UUID.init(uuidString:))
            selectedProfileID = profiles.first(where: { $0.id == saved })?.id ?? profiles.first?.id
        } catch { self.error = "Profile konnten nicht geladen werden: \(error.localizedDescription)" }
    }

    func save(_ profile: BackgroundProfile, imports: [BackgroundAssetImport]) throws {
        profiles = try store.save(profile, importing: imports)
        selectedProfileID = profile.id
        error = nil
    }

    func deleteSelectedProfile() {
        guard let selectedProfileID, !isGenerating else { return }
        do {
            profiles = try store.delete(selectedProfileID)
            self.selectedProfileID = profiles.first?.id
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func generate(camera: CameraModel) {
        guard let profile = selectedProfile, !isGenerating else { return }
        let context = context
        let address = serverAddress
        error = nil
        isGenerating = true
        generation = Task {
            defer { isGenerating = false; generation = nil }
            do {
                let data = try await client.generate(profile: profile, context: context, store: store, address: address) { self.status = $0 }
                try Task.checkCancellation()
                guard let image = NSImage(data: data),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw BackgroundError.message("Das erzeugte Bild konnte nicht geöffnet werden.")
                }
                let destination = store.directory.appendingPathComponent("last-background.png")
                let bitmap = NSBitmapImageRep(cgImage: cgImage)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw BackgroundError.message("Der Hintergrund konnte nicht gespeichert werden.")
                }
                try png.write(to: destination, options: .atomic)
                generatedImage = image
                camera.applyBackground(cgImage, name: "\(profile.name) · generiert")
                status = "Hintergrund erzeugt und aktiviert."
            } catch {
                if Task.isCancelled { status = "Generierung abgebrochen." }
                else { self.error = "Hintergrund konnte nicht erzeugt werden: \(error.localizedDescription)"; status = "" }
            }
        }
    }

    func cancel() async {
        await client.interrupt()
        generation?.cancel()
    }

    func shutdown() { generation?.cancel() }

    static func importAssets(_ urls: [URL]) throws -> [BackgroundAssetImport] {
        try urls.map { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw BackgroundError.message("„\(url.lastPathComponent)“ ist kein lesbares Bild.")
            }
            return BackgroundAssetImport(name: url.lastPathComponent, data: png, fileExtension: "png")
        }
    }
}
