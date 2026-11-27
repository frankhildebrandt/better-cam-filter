import os

/// Bounds the hand-over from the analysis queue to the composition queue to one waiting frame.
/// Each reservation gets a unique token, so frames queued before `invalidate()` can be recognized as stale.
final class FrameHandoff: Sendable {
    private struct State {
        var nextToken: UInt64 = 0
        var waiting: UInt64?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Claim the single waiting slot; nil means a frame is already waiting and this one should be dropped.
    func reserve() -> UInt64? {
        state.withLock { state in
            guard state.waiting == nil else { return nil }
            state.nextToken &+= 1
            state.waiting = state.nextToken
            return state.nextToken
        }
    }

    /// Start composing a reserved frame. False for stale or already started frames, which must be skipped.
    func begin(_ token: UInt64) -> Bool {
        state.withLock { state in
            guard state.waiting == token else { return false }
            state.waiting = nil
            return true
        }
    }

    /// Discard the waiting frame, e.g. when capture stops or the output configuration changes.
    func invalidate() {
        state.withLock { $0.waiting = nil }
    }
}
