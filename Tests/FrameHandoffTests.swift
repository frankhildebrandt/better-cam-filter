import Testing
@testable import BetterCamCore

struct FrameHandoffTests {
    @Test func onlyOneFrameMayWaitForComposition() {
        let handoff = FrameHandoff()
        let first = handoff.reserve()
        #expect(first != nil)
        #expect(handoff.reserve() == nil)
        #expect(handoff.begin(first!))
        #expect(handoff.reserve() != nil)
    }

    @Test func invalidatedFramesAreRejectedAndFreeTheSlot() {
        let handoff = FrameHandoff()
        let stale = handoff.reserve()!
        handoff.invalidate()
        let current = handoff.reserve()
        #expect(current != nil)
        #expect(!handoff.begin(stale))
        #expect(handoff.reserve() == nil) // The stale frame must not release the current reservation.
        #expect(handoff.begin(current!))
    }

    @Test func aFrameCanBeginOnlyOnce() {
        let handoff = FrameHandoff()
        let token = handoff.reserve()!
        #expect(handoff.begin(token))
        #expect(!handoff.begin(token))
    }
}
