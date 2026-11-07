import Foundation

enum CodexExecutable {
    /// Finder-launched apps do not inherit the interactive shell's PATH.
    static func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                       home: URL = FileManager.default.homeDirectoryForCurrentUser,
                       isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) throws -> URL {
        let directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init) + [
            "/opt/homebrew/bin", "/usr/local/bin", home.appendingPathComponent(".npm-global/bin").path,
            home.appendingPathComponent(".local/bin").path,
            "/Applications/Codex.app/Contents/Resources"
        ]
        for directory in directories where directory.hasPrefix("/") {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("codex")
            if isExecutable(url.path) { return url }
        }
        throw CodexProcessError.message("Codex wurde nicht gefunden. Installiere die Codex CLI und melde dich einmal mit „codex login“ an.")
    }

    static func environment(for executable: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ([executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)).joined(separator: ":")
        return environment
    }
}

enum CodexProcessError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}
