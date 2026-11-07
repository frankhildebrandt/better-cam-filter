import Foundation
import Testing
@testable import BetterCamCore

struct GestureTriggerStateTests {
    private let peace = GestureObservation(gesture: .peace, anchor: CGPoint(x: 0.5, y: 0.6))

    @Test func stableGestureFiresAfterHoldAndNeverRepeatsWhileHeld() {
        var state = GestureTriggerState()
        for time in [0.0, 0.2, 0.4] { #expect(state.update(observation: peace, at: time) == nil) }
        #expect(state.update(observation: peace, at: 0.6) == peace)
        for time in [0.8, 1.0, 1.2, 1.4] { #expect(state.update(observation: peace, at: time) == nil) }
    }

    @Test func briefDetectionDropoutAndSmallJitterDoNotRestartTheHold() {
        var state = GestureTriggerState()
        let jittered = GestureObservation(gesture: .peace, anchor: CGPoint(x: 0.53, y: 0.58))
        #expect(state.update(observation: peace, at: 0) == nil)
        #expect(state.update(observation: peace, at: 0.2) == nil)
        #expect(state.update(observation: nil, at: 0.3) == nil)
        #expect(state.update(observation: jittered, at: 0.4) == nil)
        #expect(state.update(observation: jittered, at: 0.6) == jittered)
    }

    @Test func lostFramesRequireAFreshHoldInsteadOfFiringImmediately() {
        var state = GestureTriggerState()
        #expect(state.update(observation: peace, at: 0) == nil)
        #expect(state.update(observation: peace, at: 1) == nil)
        for time in [1.2, 1.4] { #expect(state.update(observation: peace, at: time) == nil) }
        #expect(state.update(observation: peace, at: 1.6) == peace)
    }

    @Test func releasingRearmsButBriefMisclassificationDoesNot() {
        var state = GestureTriggerState()
        for time in [0.0, 0.2, 0.4, 0.6] { _ = state.update(observation: peace, at: time) }
        let other = GestureObservation(gesture: .openPalm, anchor: peace.anchor)
        #expect(state.update(observation: other, at: 0.8) == nil)
        #expect(state.update(observation: peace, at: 1.0) == nil)
        #expect(state.update(observation: nil, at: 1.1) == nil)
        #expect(state.update(observation: peace, at: 1.2) == nil)
        #expect(state.update(observation: nil, at: 1.5) == nil)
        for time in [1.6, 1.8, 2.0] { #expect(state.update(observation: peace, at: time) == nil) }
        #expect(state.update(observation: peace, at: 2.2) == peace)
    }

    @Test func changingGestureOrLargeAnchorMovementRestartsTheHold() {
        var state = GestureTriggerState()
        for time in [0.0, 0.2, 0.4] { _ = state.update(observation: peace, at: time) }
        let moved = GestureObservation(gesture: .peace, anchor: CGPoint(x: 0.8, y: 0.6))
        #expect(state.update(observation: moved, at: 0.6) == nil)
        let other = GestureObservation(gesture: .openPalm, anchor: moved.anchor)
        for time in [0.8, 1.0, 1.2] { #expect(state.update(observation: other, at: time) == nil) }
        #expect(state.update(observation: other, at: 1.4) == other)
    }

    @Test func deliberatelyChangingPoseRearmsWithoutLeavingTheCameraFrame() {
        var state = GestureTriggerState()
        for time in [0.0, 0.2, 0.4, 0.6] { _ = state.update(observation: peace, at: time) }
        let other = GestureObservation(gesture: .thumbsUp, anchor: peace.anchor)
        for time in [0.8, 1.0, 1.2] { #expect(state.update(observation: other, at: time) == nil) }
        #expect(state.update(observation: other, at: 1.4) == other)
        #expect(state.update(observation: other, at: 1.6) == nil)
    }

    @Test func resetInvalidCoordinatesAndBackwardTimeCannotReuseAHold() {
        var state = GestureTriggerState()
        for time in [0.0, 0.2, 0.4] { _ = state.update(observation: peace, at: time) }
        state.reset()
        #expect(state.update(observation: peace, at: 0.6) == nil)
        #expect(state.update(observation: peace, at: 0.2) == nil)
        #expect(state.update(observation: GestureObservation(gesture: .peace, anchor: CGPoint(x: CGFloat.nan, y: 0)), at: 0.3) == nil)
        #expect(state.update(observation: peace, at: .infinity) == nil)
        #expect(state.update(observation: peace, at: 10) == nil)
    }
}
