import Foundation

/// A private JSONL app-server process, owned by one generation's XPC connection.
@MainActor
final class CodexProcess {
    private let process: Process
    private let input: FileHandle
    private let output: FileHandle
    private let errors: FileHandle
    private var buffer = Data()
    private var messages: [Data] = []
    private var diagnostics = Data()
    private var pending: CheckedContinuation<Data, any Error>?
    private var failure: (any Error)?
    private var stopped = false
    private static let maximumMessageSize = 64 * 1024 * 1024

    var isRunning: Bool { process.isRunning }

    init(executable: URL? = nil, arguments: [String] = ["app-server", "--listen", "stdio://"]) throws {
        let executable = try executable ?? CodexExecutable.locate()
        process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = CodexExecutable.environment(for: executable)
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        input = stdin.fileHandleForWriting
        _ = fcntl(input.fileDescriptor, F_SETNOSIGPIPE, 1)
        output = stdout.fileHandleForReading
        errors = stderr.fileHandleForReading
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        output.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { @MainActor [weak self] in self?.consume(data) }
        }
        errors.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { @MainActor [weak self] in
                guard let self else { return }
                diagnostics.append(data)
                diagnostics = Data(diagnostics.suffix(8192))
            }
        }
    }

    func send(_ data: Data) async throws {
        try Task.checkCancellation()
        if let failure { throw failure }
        guard !stopped else { throw CancellationError() }
        var line = data
        line.append(0x0A)
        let input = input
        // Large reference images must not block the actor draining stdout.
        try await Task.detached { [line] in try input.write(contentsOf: line) }.value
    }

    func receive() async throws -> Data {
        try Task.checkCancellation()
        if !messages.isEmpty { return messages.removeFirst() }
        if let failure { throw failure }
        guard !stopped else { throw CancellationError() }
        guard pending == nil else { throw CodexProcessError.message("Eine Codex-Antwort wird bereits gelesen.") }
        return try await withCheckedThrowingContinuation { pending = $0 }
    }

    /// Close stdin and terminate only this owned child, including when the app disconnects.
    func stop() {
        guard !stopped else { return }
        stopped = true
        if process.isRunning {
            process.terminate()
            let process = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        let input = input
        Task.detached { try? input.close() }
        pending?.resume(throwing: CancellationError())
        pending = nil
        messages = []
        buffer = Data()
    }

    private func consume(_ data: Data) {
        guard !stopped, failure == nil else { return }
        guard !data.isEmpty else {
            let details = String(decoding: diagnostics, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            finish(CodexProcessError.message("Der Codex App Server wurde beendet.\(details.isEmpty ? "" : " " + details)"))
            return
        }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            guard buffer.distance(from: buffer.startIndex, to: newline) <= Self.maximumMessageSize else {
                finish(CodexProcessError.message("Die Codex-Antwort ist zu groß."))
                return
            }
            let message = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !message.isEmpty else { continue }
            if let pending {
                self.pending = nil
                pending.resume(returning: message)
            } else { messages.append(message) }
        }
        if buffer.count > Self.maximumMessageSize {
            finish(CodexProcessError.message("Die Codex-Antwort ist zu groß."))
        }
    }

    private func finish(_ error: any Error) {
        failure = error
        pending?.resume(throwing: error)
        pending = nil
    }
}
