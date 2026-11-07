import Foundation

final class CodexService: NSObject, CodexAppServerService, @unchecked Sendable {
    @MainActor private var process: CodexProcess?
    @MainActor private var stopped = false

    func send(_ data: Data, withReply reply: @escaping @Sendable (String?) -> Void) {
        Task { @MainActor in
            do {
                guard !stopped else { throw CancellationError() }
                if process == nil { process = try CodexProcess() }
                try await process?.send(data)
                reply(nil)
            } catch { reply(error.localizedDescription) }
        }
    }

    func receive(withReply reply: @escaping @Sendable (Data?, String?) -> Void) {
        Task { @MainActor in
            do {
                guard let process, !stopped else { throw CancellationError() }
                reply(try await process.receive(), nil)
            } catch { reply(nil, error.localizedDescription) }
        }
    }

    func stop() {
        Task { @MainActor in
            stopped = true
            process?.stop()
            process = nil
        }
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let service = CodexService()
        connection.exportedInterface = NSXPCInterface(with: CodexAppServerService.self)
        connection.exportedObject = service
        connection.invalidationHandler = { service.stop() }
        connection.interruptionHandler = { service.stop() }
        connection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
