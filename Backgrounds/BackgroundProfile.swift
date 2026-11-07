import Foundation

struct BackgroundAsset: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var filename: String
}

struct BackgroundProfile: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var prePrompt = ""
    var assets: [BackgroundAsset] = []

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func prompt(context: String) -> String {
        """
        Erzeuge genau ein Hintergrundbild für eine virtuelle Webcam im Querformat 16:9.
        Verwende das Bildgenerierungswerkzeug. Keine Personen im Bild; halte die Bildmitte ruhig,
        da dort später eine Person eingeblendet wird. Erzeuge ein fertiges Bild, keine Anleitung.

        Feste Vorgaben aus dem Profil „\(name)“:
        \(prePrompt)

        Alle \(assets.count) angehängten Referenzbilder gehören dauerhaft zu diesem Profil.
        Verwende jedes davon als visuelle Vorgabe, auch wenn der Zusatzkontext es nicht erwähnt.

        Zusätzlicher Kontext für dieses Bild:
        \(context.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }
}

struct BackgroundAssetImport: Sendable {
    var name: String
    var data: Data
    /// The image MIME type is determined when importing, rather than trusting its filename.
    var fileExtension: String
}

struct BackgroundProfileStore: Sendable {
    let directory: URL

    static var applicationStore: Self {
        Self(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BetterCam/Backgrounds", isDirectory: true))
    }

    private var manifest: URL { directory.appendingPathComponent("profiles.json") }

    func load() throws -> [BackgroundProfile] {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return [] }
        return try JSONDecoder().decode([BackgroundProfile].self, from: Data(contentsOf: manifest))
    }

    func assetURL(_ asset: BackgroundAsset) throws -> URL {
        guard asset.filename == URL(fileURLWithPath: asset.filename).lastPathComponent,
              !asset.filename.isEmpty, asset.filename != ".", asset.filename != ".." else {
            throw BackgroundError.message("Ungültiger Asset-Dateiname im Profil.")
        }
        return directory.appendingPathComponent("Assets", isDirectory: true).appendingPathComponent(asset.filename)
    }

    func save(_ profile: BackgroundProfile, importing imports: [BackgroundAssetImport]) throws -> [BackgroundProfile] {
        guard profile.isValid else { throw BackgroundError.message("Bitte einen Profilnamen eingeben.") }
        var profiles = try load()
        var updated = profile
        let assetDirectory = directory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        var written: [URL] = []
        do {
            for item in imports {
                let id = UUID()
                let asset = BackgroundAsset(id: id, name: item.name, filename: "\(id.uuidString).\(item.fileExtension)")
                let url = try assetURL(asset)
                try item.data.write(to: url, options: .atomic)
                written.append(url)
                updated.assets.append(asset)
            }
            if let index = profiles.firstIndex(where: { $0.id == updated.id }) { profiles[index] = updated }
            else { profiles.append(updated) }
            try write(profiles)
        } catch {
            for url in written { try? FileManager.default.removeItem(at: url) }
            throw error
        }
        removeUnusedAssets(profiles)
        return profiles
    }

    func delete(_ id: UUID) throws -> [BackgroundProfile] {
        let profiles = try load().filter { $0.id != id }
        try write(profiles)
        removeUnusedAssets(profiles)
        return profiles
    }

    func generationDirectory() throws -> URL {
        let url = directory.appendingPathComponent("Generations/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ profiles: [BackgroundProfile]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(profiles).write(to: manifest, options: .atomic)
    }

    private func removeUnusedAssets(_ profiles: [BackgroundProfile]) {
        let retained = Set(profiles.flatMap(\.assets).map(\.filename))
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("Assets"), includingPropertiesForKeys: nil)) ?? []
        for file in files where !retained.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
    }
}

enum BackgroundError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}
