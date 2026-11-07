import Foundation

@MainActor
protocol CodexConnection: Sendable {
    func send(_ text: String) async throws
    func receive() async throws -> Data
    nonisolated func cancel()
}

private final class CodexWebSocketConnection: CodexConnection {
    private let session: URLSession
    private let socket: URLSessionWebSocketTask

    init(url: URL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 900
        session = URLSession(configuration: configuration)
        socket = session.webSocketTask(with: url)
        socket.maximumMessageSize = 64 * 1024 * 1024
        socket.resume()
    }

    func send(_ text: String) async throws { try await socket.send(.string(text)) }

    func receive() async throws -> Data {
        switch try await socket.receive() {
        case .string(let text): return Data(text.utf8)
        case .data(let bytes): return bytes
        @unknown default: throw BackgroundError.message("Unbekannte Antwort vom Codex App Server.")
        }
    }

    nonisolated func cancel() {
        socket.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
}

/// One connection and fresh thread per image, so profile/context never leaks between generations.
@MainActor
final class CodexBackgroundClient {
    private var connection: (any CodexConnection)?
    private let connect: (URL) -> any CodexConnection
    private var nextID = 0
    private var buffered: [[String: Any]] = []
    private var threadID: String?
    private var turnID: String?

    init(connect: @escaping (URL) -> any CodexConnection = { CodexWebSocketConnection(url: $0) }) {
        self.connect = connect
    }

    static func endpoint(_ address: String) throws -> URL {
        guard let url = URL(string: address), url.scheme == "ws",
              let host = url.host, ["127.0.0.1", "localhost", "[::1]", "::1"].contains(host),
              url.user == nil, url.password == nil, url.fragment == nil else {
            throw BackgroundError.message("Bitte einen lokalen App Server angeben, z. B. ws://127.0.0.1:4500.")
        }
        return url
    }

    func generate(profile: BackgroundProfile, context: String, store: BackgroundProfileStore,
                  address: String, status: (String) -> Void) async throws -> Data {
        let url = try Self.endpoint(address)
        let workspace = try store.generationDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        // Send all profile assets with every request; fail if one is missing instead of silently omitting it.
        var input: [[String: Any]] = [["type": "text", "text": profile.prompt(context: context) + "\nSpeichere das fertige Bild als \(workspace.path)/background.png."]]
        for asset in profile.assets {
            let data = try Data(contentsOf: store.assetURL(asset))
            let mime = asset.filename.hasSuffix(".jpg") ? "image/jpeg" : "image/png"
            input.append(["type": "image", "url": "data:\(mime);base64,\(data.base64EncodedString())"])
        }
        let connection = connect(url)
        self.connection = connection
        nextID = 0
        buffered = []
        threadID = nil
        turnID = nil
        let timeout = Task {
            try await Task.sleep(for: .seconds(900))
            await interrupt()
            connection.cancel()
        }
        defer {
            timeout.cancel()
            connection.cancel()
            self.connection = nil
        }
        return try await withTaskCancellationHandler {
            status("Verbinde mit Codex …")
            _ = try await request("initialize", params: [
                "clientInfo": ["name": "bettercam", "title": "BetterCam", "version": "0.1.0"],
                "capabilities": ["experimentalApi": true]
            ])
            try await send(["method": "initialized", "params": [:]])
            let thread = try await request("thread/start", params: [
                "cwd": workspace.path, "approvalPolicy": "never", "sandbox": "workspace-write",
                "config": ["features.image_generation": true], "ephemeral": true
            ])
            guard let id = (thread["thread"] as? [String: Any])?["id"] as? String else {
                throw BackgroundError.message("Codex hat keinen Thread zurückgegeben.")
            }
            threadID = id
            status("Codex erzeugt deinen Hintergrund …")
            let response = try await request("turn/start", params: ["threadId": id, "input": input])
            guard let started = response["turn"] as? [String: Any], let startedID = started["id"] as? String else {
                throw BackgroundError.message("Codex hat keine Generierung gestartet.")
            }
            turnID = startedID
            var generated: [String: Any]?
            while true {
                try Task.checkCancellation()
                let message: [String: Any]
                if !buffered.isEmpty { message = buffered.removeFirst() }
                else { message = try await receive() }
                if try await respondToServerRequest(message) { continue }
                guard let params = message["params"] as? [String: Any], params["threadId"] as? String == id else { continue }
                let method = message["method"] as? String
                if method == "item/completed", params["turnId"] as? String == startedID,
                   let item = params["item"] as? [String: Any], item["type"] as? String == "imageGeneration" {
                    generated = item
                }
                if method == "item/started", params["turnId"] as? String == startedID,
                   let item = params["item"] as? [String: Any], item["type"] as? String == "imageGeneration" {
                    status("Bild wird gerendert …")
                }
                if method == "turn/completed", let turn = params["turn"] as? [String: Any], turn["id"] as? String == startedID {
                    guard turn["status"] as? String == "completed" else {
                        let error = (turn["error"] as? [String: Any])?["message"] as? String
                        throw BackgroundError.message(error ?? "Die Bildgenerierung wurde unterbrochen.")
                    }
                    for item in turn["items"] as? [[String: Any]] ?? [] where item["type"] as? String == "imageGeneration" { generated = item }
                    break
                }
            }
            status("Hintergrund wird geladen …")
            if let failure = generated?["failure"] as? [String: Any], failure["type"] as? String == "usageLimitExceeded" {
                throw BackgroundError.message("Das Codex-Nutzungslimit für Bildgenerierung ist erreicht. Bitte später erneut versuchen.")
            }
            if let encoded = generated?["result"] as? String, let data = Self.imageData(encoded) { return data }
            // savedPath is server-side; fs/readFile also works when the app sandbox cannot read that path.
            let path = generated?["savedPath"] as? String ?? workspace.appendingPathComponent("background.png").path
            do {
                let file = try await request("fs/readFile", params: ["path": path])
                if let encoded = file["dataBase64"] as? String, let data = Data(base64Encoded: encoded), !data.isEmpty { return data }
            } catch {
                throw BackgroundError.message("Codex hat kein lesbares Bild geliefert. Prüfe, ob dein Codex-Konto Bildgenerierung unterstützt. \(error.localizedDescription)")
            }
            throw BackgroundError.message("Codex hat kein Bild geliefert. Prüfe die Bildgenerierung in deinem Codex App Server.")
        } onCancel: {
            connection.cancel()
        }
    }

    /// Interrupt the active server turn before closing the connection.
    func interrupt() async {
        guard let threadID, let turnID else { return }
        nextID += 1
        try? await send(["id": nextID, "method": "turn/interrupt", "params": ["threadId": threadID, "turnId": turnID]])
    }

    static func imageData(_ encoded: String) -> Data? {
        let payload = encoded.hasPrefix("data:") ? encoded.components(separatedBy: ",").dropFirst().joined(separator: ",") : encoded
        guard let data = Data(base64Encoded: payload), !data.isEmpty else { return nil }
        return data
    }

    private func request(_ method: String, params: [String: Any]) async throws -> [String: Any] {
        nextID += 1
        let id = nextID
        try await send(["id": id, "method": method, "params": params])
        while true {
            try Task.checkCancellation()
            let message = try await receive()
            if message["method"] != nil {
                if try await respondToServerRequest(message) { continue }
                buffered.append(message)
                continue
            }
            guard message["id"] as? Int == id else { continue }
            if let error = message["error"] as? [String: Any] {
                throw BackgroundError.message(error["message"] as? String ?? "Fehler im Codex App Server.")
            }
            return message["result"] as? [String: Any] ?? [:]
        }
    }

    private func respondToServerRequest(_ message: [String: Any]) async throws -> Bool {
        guard let id = message["id"], let method = message["method"] as? String else { return false }
        if method == "item/commandExecution/requestApproval" || method == "item/fileChange/requestApproval" {
            try await send(["id": id, "result": ["decision": "decline"]])
        } else {
            try await send(["id": id, "error": ["code": -32601, "message": "BetterCam unterstützt diese interaktive Anfrage nicht."]])
        }
        return true
    }

    private func send(_ message: [String: Any]) async throws {
        guard let connection else { throw BackgroundError.message("Keine Verbindung zum Codex App Server.") }
        let data = try JSONSerialization.data(withJSONObject: message)
        try await connection.send(String(decoding: data, as: UTF8.self))
    }

    private func receive() async throws -> [String: Any] {
        guard let connection else { throw BackgroundError.message("Keine Verbindung zum Codex App Server.") }
        let data = try await connection.receive()
        guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackgroundError.message("Ungültige Antwort vom Codex App Server.")
        }
        return message
    }
}
