import CryptoKit
import Foundation
import Testing
@testable import BetterCamCore

struct SegmentationModelDownloaderTests {
    private let content = Data("test Core ML model bytes".utf8)

    @Test func verifiedDownloadKeepsItsOwnedFileUntilTheCallerRemovesIt() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = content
        let downloader = SegmentationModelDownloader(temporaryRoot: root) { source, destination, progress in
            progress(0.5)
            try bytes.write(to: destination)
            return response(source)
        }
        let file = try await downloader.download(model()) { _ in }
        #expect(try Data(contentsOf: file) == content)
        #expect(file.lastPathComponent == "Foreground.mlmodel")
        #expect(file.deletingLastPathComponent().deletingLastPathComponent() == root)
    }

    @Test(arguments: [404, 500])
    func httpFailuresRemoveAllStagedFiles(status: Int) async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = content
        let downloader = SegmentationModelDownloader(temporaryRoot: root) { source, destination, _ in
            try bytes.write(to: destination)
            return response(source, status: status)
        }
        await #expect(throws: SegmentationDownloadError.self) { try await downloader.download(model()) { _ in } }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func corruptContentAndWrongSizeCannotBecomeDownloadedModels() async throws {
        for bytes in [Data("wrong bytes same length!".utf8), Data("short".utf8)] {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let downloader = SegmentationModelDownloader(temporaryRoot: root) { source, destination, _ in
                try bytes.write(to: destination)
                return response(source)
            }
            await #expect(throws: SegmentationDownloadError.self) { try await downloader.download(model()) { _ in } }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        }
    }

    @Test func sameSizeCorruptionFailsThePinnedChecksum() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var wrong = content
        wrong[0] ^= 1
        let bytes = wrong
        let downloader = SegmentationModelDownloader(temporaryRoot: root) { source, destination, _ in
            try bytes.write(to: destination)
            return response(source)
        }
        await #expect(throws: SegmentationDownloadError.self) { try await downloader.download(model()) { _ in } }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func cancellationRemovesAPartialDownload() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (started, signal) = AsyncStream<Void>.makeStream()
        let downloader = SegmentationModelDownloader(temporaryRoot: root) { source, destination, _ in
            try Data("partial".utf8).write(to: destination)
            signal.yield(())
            signal.finish()
            try await Task.sleep(for: .seconds(30))
            return response(source)
        }
        let entry = model()
        let task = Task { try await downloader.download(entry) { _ in } }
        _ = await started.first(where: { _ in true })
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        if FileManager.default.fileExists(atPath: root.path) {
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        }
    }

    @Test func insecureDownloadsAndUnsafeFileNamesNeverReachTransport() async {
        let downloader = SegmentationModelDownloader { _, _, _ in
            Issue.record("Invalid catalog entries must not start a transfer")
            throw CancellationError()
        }
        for entry in [model(url: URL(string: "http://models.example/model")!), model(fileName: "../escape.mlmodel")] {
            await #expect(throws: SegmentationDownloadError.self) { try await downloader.download(entry) { _ in } }
        }
    }

    @Test func cancellationBeforeStartingDoesNotCreateAStagedDownload() async {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = SegmentationModelDownloader(temporaryRoot: root) { _, _, _ in
            Issue.record("A cancelled download must not start a transfer")
            throw CancellationError()
        }
        let entry = model()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await downloader.download(entry) { _ in }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    private func model(url: URL = URL(string: "https://models.example/Foreground.mlmodel")!,
                       fileName: String = "Foreground.mlmodel") -> DownloadableSegmentationModel {
        DownloadableSegmentationModel(id: "test", title: "Test", summary: "Test model", downloadURL: url,
            sourceURL: URL(string: "https://models.example")!, license: "Test", byteCount: Int64(content.count),
            sha256: SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined(), fileName: fileName)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private func response(_ url: URL, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}
