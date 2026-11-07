import Foundation

/// Shared XPC contract; the helper can launch only Codex with a fixed stdio transport.
@objc(CodexAppServerService) protocol CodexAppServerService {
    func send(_ data: Data, withReply reply: @escaping @Sendable (String?) -> Void)
    func receive(withReply reply: @escaping @Sendable (Data?, String?) -> Void)
}
