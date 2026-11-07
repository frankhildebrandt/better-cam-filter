import CryptoKit
import Foundation

enum SegmentationDownloadError: LocalizedError {
    case invalidCatalogEntry, insecureURL, invalidResponse, httpStatus(Int), sizeMismatch, checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidCatalogEntry: "Der Modelleintrag enthält ungültige Downloadinformationen."
        case .insecureURL: "Modelle können nur über eine sichere HTTPS-Verbindung geladen werden."
        case .invalidResponse: "Der Modellserver hat keine gültige Downloadantwort geliefert."
        case .httpStatus(let code): "Der Modelldownload ist fehlgeschlagen (HTTP \(code))."
        case .sizeMismatch: "Die heruntergeladene Modelldatei hat nicht die erwartete Größe."
        case .checksumMismatch: "Die heruntergeladene Modelldatei stimmt nicht mit der geprüften Version überein."
        }
    }
}

typealias SegmentationDownloadTransport = @Sendable (
    URL, URL, @escaping @Sendable (Double) -> Void
) async throws -> HTTPURLResponse

struct SegmentationModelDownloader: Sendable {
    private let temporaryRoot: URL
    private let transport: SegmentationDownloadTransport

    init(temporaryRoot: URL = FileManager.default.temporaryDirectory,
         transport: @escaping SegmentationDownloadTransport = { source, destination, progress in
             try await ModelDownloadTransfer().download(source, to: destination, progress: progress)
         }) {
        self.temporaryRoot = temporaryRoot
        self.transport = transport
    }

    /// Return an owned temporary model only after its fixed byte count and SHA-256 match the catalog.
    func download(_ model: DownloadableSegmentationModel,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard model.downloadURL.scheme?.lowercased() == "https", model.downloadURL.host != nil else {
            throw SegmentationDownloadError.insecureURL
        }
        guard !model.fileName.isEmpty, model.fileName != ".", model.fileName != "..",
              !model.fileName.contains("/"), !model.fileName.contains("\\"),
              model.byteCount > 0, model.sha256.count == 64,
              model.sha256.allSatisfy(\.isHexDigit) else { throw SegmentationDownloadError.invalidCatalogEntry }
        try Task.checkCancellation()
        let directory = temporaryRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: directory) } }
        let file = directory.appendingPathComponent(model.fileName)
        progress(0)
        let response = try await transport(model.downloadURL, file, progress)
        guard (200...299).contains(response.statusCode) else { throw SegmentationDownloadError.httpStatus(response.statusCode) }
        guard response.url?.scheme?.lowercased() == "https" else { throw SegmentationDownloadError.insecureURL }
        try Task.checkCancellation()
        let bytes = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber
        guard bytes?.int64Value == model.byteCount else { throw SegmentationDownloadError.sizeMismatch }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == model.sha256.lowercased() else { throw SegmentationDownloadError.checksumMismatch }
        try Task.checkCancellation()
        progress(1)
        complete = true
        return file
    }
}

/// URLSession owns its temporary file only during the delegate callback, so copy before returning.
private final class ModelDownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<HTTPURLResponse, any Error>?
    private var session: URLSession?
    private var destination: URL?
    private var progress: (@Sendable (Double) -> Void)?
    private var cancelled = false

    func download(_ source: URL, to destination: URL,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> HTTPURLResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                self.destination = destination
                self.progress = progress
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 1_800
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let task = session.downloadTask(with: source)
                lock.unlock()
                task.resume()
            }
        } onCancel: { self.cancel() }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        lock.lock()
        let progress = self.progress
        lock.unlock()
        progress?(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        lock.lock()
        let destination = self.destination
        lock.unlock()
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, let destination else {
                throw SegmentationDownloadError.invalidResponse
            }
            try FileManager.default.copyItem(at: location, to: destination)
            finish(.success(response))
        } catch { finish(.failure(error)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error { finish(.failure(error)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard request.url?.scheme?.lowercased() == "https" else {
            completionHandler(nil)
            finish(.failure(SegmentationDownloadError.insecureURL))
            return
        }
        completionHandler(request)
    }

    private func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
        finish(.failure(CancellationError()))
    }

    private func finish(_ result: Result<HTTPURLResponse, any Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let session = self.session
        self.session = nil
        progress = nil
        lock.unlock()
        continuation?.resume(with: result)
        session?.invalidateAndCancel()
    }
}
