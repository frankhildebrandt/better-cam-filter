import Foundation

struct GeneratedBackground: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var createdAt = Date()
}

struct BackgroundLibraryStore: Sendable {
    let directory: URL

    private var libraryDirectory: URL { directory.appendingPathComponent("Library", isDirectory: true) }
    private var manifest: URL { libraryDirectory.appendingPathComponent("library.json") }

    /// Load newest entries first, importing the previous single background on first use.
    func load() throws -> [GeneratedBackground] {
        if FileManager.default.fileExists(atPath: manifest.path) {
            return try JSONDecoder().decode([GeneratedBackground].self, from: Data(contentsOf: manifest))
        }
        let legacy = directory.appendingPathComponent("last-background.png")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return [] }
        let entry = GeneratedBackground(name: "Bisheriger Hintergrund")
        try write(Data(contentsOf: legacy), entry: entry, entries: [entry])
        return [entry]
    }

    func imageURL(_ entry: GeneratedBackground) -> URL {
        libraryDirectory.appendingPathComponent("\(entry.id.uuidString).png")
    }

    func save(_ png: Data, name: String) throws -> [GeneratedBackground] {
        let entries = try load()
        let entry = GeneratedBackground(name: name)
        let updated = [entry] + entries
        try write(png, entry: entry, entries: updated)
        return updated
    }

    /// Commit metadata only after the image is safely stored; roll back on failure.
    private func write(_ png: Data, entry: GeneratedBackground, entries: [GeneratedBackground]) throws {
        try FileManager.default.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        let destination = imageURL(entry)
        try png.write(to: destination, options: .atomic)
        do {
            try JSONEncoder().encode(entries).write(to: manifest, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
