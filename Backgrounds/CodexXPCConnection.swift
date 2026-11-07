import Foundation

final class CodexXPCConnection: CodexConnection {
    private nonisolated let channel = CodexXPCChannel()

    func send(_ text: String) async throws { try await channel.send(text) }
    func receive() async throws -> Data { try await channel.receive() }
    nonisolated func cancel() { channel.cancel() }
}

/// Keeps continuations safe across XPC's reply, invalidation and cancellation queues.
private final class CodexXPCChannel: @unchecked Sendable {
    private let session: NSXPCConnection
    private let lock = NSLock()
    private var pending: [UUID: CheckedContinuation<Data?, any Error>] = [:]
    private var closed = false

    nonisolated init() {
        session = NSXPCConnection(serviceName: "de.bettercam.CodexServer")
        session.remoteObjectInterface = NSXPCInterface(with: CodexAppServerService.self)
        session.invalidationHandler = { [weak self] in self?.failAll() }
        session.interruptionHandler = { [weak self] in self?.cancel() }
        session.resume()
    }

    func send(_ text: String) async throws {
        _ = try await request { proxy, reply in
            proxy.send(Data(text.utf8)) { reply(nil, $0) }
        }
    }

    func receive() async throws -> Data {
        guard let data = try await request({ proxy, reply in proxy.receive(withReply: reply) }) else {
            throw BackgroundError.message("Keine Antwort vom Codex-Hilfsprozess.")
        }
        return data
    }

    nonisolated func cancel() {
        failAll()
        session.invalidate()
    }

    private nonisolated func request(
        _ operation: (any CodexAppServerService, @escaping @Sendable (Data?, String?) -> Void) -> Void
    ) async throws -> Data? {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let id = UUID()
                let registered = lock.withLock {
                    guard !closed else { return false }
                    pending[id] = continuation
                    return true
                }
                guard registered else { continuation.resume(throwing: CancellationError()); return }
                let proxy = session.remoteObjectProxyWithErrorHandler { [weak self] error in
                    self?.finish(id, data: nil, error: "Codex-Hilfsprozess nicht erreichbar: \(error.localizedDescription)")
                }
                guard let service = proxy as? any CodexAppServerService else {
                    finish(id, data: nil, error: "Codex-Hilfsprozess nicht erreichbar.")
                    return
                }
                operation(service) { [weak self] data, error in self?.finish(id, data: data, error: error) }
            }
        } onCancel: { cancel() }
    }

    private nonisolated func finish(_ id: UUID, data: Data?, error: String?) {
        let continuation = lock.withLock { pending.removeValue(forKey: id) }
        if let error { continuation?.resume(throwing: BackgroundError.message(error)) }
        else { continuation?.resume(returning: data) }
    }

    private nonisolated func failAll() {
        let continuations = lock.withLock {
            closed = true
            let continuations = Array(pending.values)
            pending = [:]
            return continuations
        }
        for continuation in continuations {
            continuation.resume(throwing: BackgroundError.message("Die Verbindung zum Codex-Hilfsprozess wurde beendet. Bitte erneut versuchen."))
        }
    }
}
