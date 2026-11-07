import Foundation
import Testing
@testable import CodexServerKit

@MainActor
struct CodexProcessTests {
    @Test func exchangesLargeJSONLinesWithoutBlockingAndPreservesMessageBoundaries() async throws {
        let process = try fixture("while IFS= read -r line; do printf '%s\\n%s\\n' \"$line\" '{\"notification\":true}'; done")
        defer { process.stop() }
        let message = Data("{\"image\":\"\(String(repeating: "a", count: 256 * 1024))\"}".utf8)
        try await process.send(message)
        #expect(try await process.receive() == message)
        #expect(try await process.receive() == Data("{\"notification\":true}".utf8))
    }

    @Test func readsSplitAndBatchedResponsesAndIgnoresStderr() async throws {
        let process = try fixture("printf 'diagnostic only' >&2; printf '{\"id\":'; printf '1}\\n{\"id\":2}\\n'; IFS= read -r line")
        defer { process.stop() }
        #expect(try await process.receive() == Data("{\"id\":1}".utf8))
        #expect(try await process.receive() == Data("{\"id\":2}".utf8))
    }

    @Test func unexpectedExitFailsPendingReceive() async throws {
        let process = try fixture("exit 7")
        defer { process.stop() }
        await #expect(throws: CodexProcessError.self) { try await process.receive() }
    }

    @Test func stopReleasesPendingReceiveAndTerminatesOwnedProcess() async throws {
        let process = try fixture("IFS= read -r line")
        let receive = Task { try await process.receive() }
        await Task.yield()
        process.stop()
        process.stop()
        await #expect(throws: CancellationError.self) { try await receive.value }
        await #expect(throws: CancellationError.self) { try await process.send(Data()) }
        for _ in 0..<300 {
            if !process.isRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!process.isRunning)
    }

    @Test func stopUnblocksLargeWriteEvenWhenChildIgnoresTermination() async throws {
        let process = try fixture("trap '' TERM; printf 'ready\\n'; exec /bin/sleep 30")
        defer { process.stop() }
        #expect(try await process.receive() == Data("ready".utf8))
        let write = Task { try await process.send(Data(repeating: 65, count: 1024 * 1024)) }
        try await Task.sleep(for: .milliseconds(20))
        process.stop()
        await #expect(throws: (any Error).self) { try await write.value }
        for _ in 0..<300 {
            if !process.isRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!process.isRunning)
    }

    @Test func findsHomebrewWhenFinderPathIsMinimal() throws {
        let url = try CodexExecutable.locate(environment: ["PATH": "/usr/bin:/bin"], isExecutable: { $0 == "/opt/homebrew/bin/codex" })
        #expect(url.path == "/opt/homebrew/bin/codex")
    }

    @Test func prefersExplicitPathAndRejectsMissingCLI() throws {
        let url = try CodexExecutable.locate(environment: ["PATH": "/custom/bin:/usr/bin"], isExecutable: { $0.hasSuffix("/codex") })
        #expect(url.path == "/custom/bin/codex")
        #expect(throws: CodexProcessError.self) { try CodexExecutable.locate(isExecutable: { _ in false }) }
    }

    private func fixture(_ script: String) throws -> CodexProcess {
        try CodexProcess(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script])
    }
}
