import Foundation
import Testing
@testable import BackgroundKit

@MainActor
struct CodexBackgroundClientTests {
    @Test func automaticModeUsesOwnedConnectionAndManualModeUsesConfiguredEndpoint() async throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var endpoints: [URL?] = []
        let client = CodexBackgroundClient(connect: { endpoints.append($0); return MockCodexConnection() })
        _ = try await client.generate(profile: BackgroundProfile(name: "Studio"), context: "", store: store,
                                      address: "invalid-unused-address", status: { _ in })
        _ = try await client.generate(profile: BackgroundProfile(name: "Studio"), context: "", store: store,
                                      address: "ws://localhost:9876", automaticallyStartServer: false, status: { _ in })
        #expect(endpoints.count == 2)
        #expect(endpoints[0] == nil)
        #expect(endpoints[1]?.absoluteString == "ws://localhost:9876")
    }

    @Test func sendsEveryAssetAndCombinesFixedAndAdditionalContext() async throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let bytes = Data([1, 2, 3])
        let profiles = try store.save(BackgroundProfile(name: "Marke", prePrompt: "Immer blaue Wände"), importing: [
            .init(name: "logo.png", data: bytes, fileExtension: "png"),
            .init(name: "style.png", data: bytes, fileExtension: "png")
        ])
        let profile = try #require(profiles.first)
        let mock = MockCodexConnection()
        let client = CodexBackgroundClient(connect: { _ in mock })
        let result = try await client.generate(profile: profile, context: "Abendlicht", store: store,
                                               address: "ws://127.0.0.1:4500", status: { _ in })
        #expect(result == mock.image)
        let initialize = try #require(mock.sent.first)
        #expect(initialize["method"] as? String == "initialize")
        #expect(mock.sent[1]["method"] as? String == "initialized")
        let start = try #require(mock.sent.first { $0["method"] as? String == "turn/start" })
        let params = try #require(start["params"] as? [String: Any])
        let inputs = try #require(params["input"] as? [[String: Any]])
        #expect(inputs.count == 3)
        let text = try #require(inputs.first?["text"] as? String)
        #expect(text.contains("Immer blaue Wände"))
        #expect(text.contains("Abendlicht"))
        #expect(inputs.dropFirst().allSatisfy { $0["url"] as? String == "data:image/png;base64,\(bytes.base64EncodedString())" })
        _ = try await client.generate(profile: profile, context: "Morgenlicht", store: store,
                                       address: "ws://127.0.0.1:4500", status: { _ in })
        let turns = mock.sent.filter { $0["method"] as? String == "turn/start" }
        #expect(turns.count == 2)
        let second = try #require((turns.last?["params"] as? [String: Any])?["input"] as? [[String: Any]])
        #expect(second.count == 3)
        #expect((second[0]["text"] as? String)?.contains("Abendlicht") == false)
        #expect((second[0]["text"] as? String)?.contains("Morgenlicht") == true)
        #expect(second.dropFirst().allSatisfy { $0["url"] as? String == "data:image/png;base64,\(bytes.base64EncodedString())" })
    }

    @Test func readsServerSideImageAfterEarlyCompletionEvents() async throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let mock = MockCodexConnection(serverFile: true)
        let client = CodexBackgroundClient(connect: { _ in mock })
        let result = try await client.generate(profile: BackgroundProfile(name: "Studio"), context: "", store: store,
                                               address: "ws://localhost:4500", status: { _ in })
        #expect(result == mock.image)
        let read = try #require(mock.sent.first { $0["method"] as? String == "fs/readFile" })
        #expect((read["params"] as? [String: Any])?["path"] as? String == "/server/generated.png")
        let workspaces = try FileManager.default.contentsOfDirectory(
            at: store.directory.appendingPathComponent("Generations"), includingPropertiesForKeys: nil)
        #expect(workspaces.isEmpty)
    }

    @Test func propagatesFailedTurnAndDeclinesInteractiveApproval() async throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let mock = MockCodexConnection(failure: true)
        let client = CodexBackgroundClient(connect: { _ in mock })
        do {
            _ = try await client.generate(profile: BackgroundProfile(name: "Studio"), context: "", store: store,
                                          address: "ws://127.0.0.1:4500", status: { _ in })
            Issue.record("A failed turn must throw")
        } catch { #expect(error.localizedDescription == "Usage limit reached") }
        let decline = try #require(mock.sent.first { $0["id"] as? Int == 77 })
        #expect((decline["result"] as? [String: Any])?["decision"] as? String == "decline")
    }

    @Test func missingAssetFailsBeforeSendingAnything() async throws {
        let store = temporaryStore()
        let mock = MockCodexConnection()
        let client = CodexBackgroundClient(connect: { _ in mock })
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let profile = BackgroundProfile(name: "Studio", assets: [BackgroundAsset(id: UUID(), name: "Missing", filename: "missing.png")])
        await #expect(throws: (any Error).self) {
            try await client.generate(profile: profile, context: "", store: store,
                                      address: "ws://127.0.0.1:4500", status: { _ in })
        }
        #expect(mock.sent.isEmpty)
    }

    @Test func cancellationInterruptsTurnAndClosesPendingReceive() async throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let mock = MockCodexConnection(pause: true)
        let client = CodexBackgroundClient(connect: { _ in mock })
        let generation = Task {
            try await client.generate(profile: BackgroundProfile(name: "Studio"), context: "", store: store,
                                      address: "ws://127.0.0.1:4500", status: { _ in })
        }
        await mock.waitUntilPaused()
        await client.interrupt()
        generation.cancel()
        await #expect(throws: CancellationError.self) { try await generation.value }
        let interrupt = try #require(mock.sent.first { $0["method"] as? String == "turn/interrupt" })
        let params = try #require(interrupt["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-1")
        #expect(params["turnId"] as? String == "turn-1")
    }

    @Test func rejectsRemoteEndpointsAndDecodesInlineData() throws {
        #expect(throws: BackgroundError.self) { try CodexBackgroundClient.endpoint("ws://example.com:4500") }
        #expect(throws: BackgroundError.self) { try CodexBackgroundClient.endpoint("https://127.0.0.1:4500") }
        #expect(CodexBackgroundClient.imageData("data:image/png;base64,AQID") == Data([1, 2, 3]))
        #expect(CodexBackgroundClient.imageData("") == nil)
    }

    private func temporaryStore() -> BackgroundProfileStore {
        BackgroundProfileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
}

/// Exercises the actual JSON-RPC client, including notifications arriving before turn/start's response.
@MainActor
private final class MockCodexConnection: CodexConnection {
    var sent: [[String: Any]] = []
    var incoming: [[String: Any]] = []
    let image = Data([137, 80, 78, 71])
    let serverFile: Bool
    let failure: Bool
    let pause: Bool
    private var pendingReceive: CheckedContinuation<Data, any Error>?
    private var pauseObserver: CheckedContinuation<Void, Never>?

    init(serverFile: Bool = false, failure: Bool = false, pause: Bool = false) {
        self.serverFile = serverFile; self.failure = failure; self.pause = pause
    }

    func send(_ text: String) async throws {
        let message = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        sent.append(message)
        guard let method = message["method"] as? String, let id = message["id"] else { return }
        switch method {
        case "initialize": incoming.append(["id": id, "result": [:]])
        case "thread/start": incoming.append(["id": id, "result": ["thread": ["id": "thread-1"]]])
        case "turn/start":
            if pause {
                incoming.append(["id": id, "result": ["turn": ["id": "turn-1", "status": "inProgress"]]])
                return
            }
            let item: [String: Any] = serverFile
                ? ["type": "imageGeneration", "status": "completed", "savedPath": "/server/generated.png", "fileId": "file-1"]
                : ["type": "imageGeneration", "status": "completed", "result": image.base64EncodedString()]
            // A different client's notification must be ignored.
            incoming.append(["method": "turn/completed", "params": ["threadId": "other", "turn": ["id": "turn-1", "status": "failed"]]])
            if failure {
                incoming.append(["id": 77, "method": "item/commandExecution/requestApproval", "params": [:]])
            }
            incoming.append(["method": "item/completed", "params": ["threadId": "thread-1", "turnId": "turn-1", "item": item]])
            incoming.append(["method": "turn/completed", "params": ["threadId": "thread-1", "turn": [
                "id": "turn-1", "status": failure ? "failed" : "completed", "error": ["message": "Usage limit reached"]
            ]]])
            incoming.append(["id": id, "result": ["turn": ["id": "turn-1", "status": "inProgress"]]])
        case "fs/readFile": incoming.append(["id": id, "result": ["dataBase64": image.base64EncodedString()]])
        case "turn/interrupt": break
        default: throw BackgroundError.message("Unexpected request: \(method)")
        }
    }

    func receive() async throws -> Data {
        if incoming.isEmpty && pause {
            return try await withCheckedThrowingContinuation {
                pendingReceive = $0
                pauseObserver?.resume()
                pauseObserver = nil
            }
        }
        guard !incoming.isEmpty else { throw BackgroundError.message("No queued mock response") }
        return try JSONSerialization.data(withJSONObject: incoming.removeFirst())
    }

    func waitUntilPaused() async {
        if pendingReceive != nil { return }
        await withCheckedContinuation { pauseObserver = $0 }
    }

    nonisolated func cancel() {
        Task { @MainActor in
            pendingReceive?.resume(throwing: CancellationError())
            pendingReceive = nil
        }
    }
}
