import CoreGraphics
import Foundation
import Testing
@testable import BetterCamCore

struct GestureReactionPlaybackTests {
    @Test func disabledRecognitionStillAllowsCompatibleManualPreviews() {
        var playback = GestureReactionPlayback()
        feed(.peace, to: &playback, startingAt: 1)
        #expect(playback.active == nil)
        playback.preview(.bunnyPeek, for: .peace, at: 2)
        #expect(playback.active?.reaction == .bunnyPeek)
        playback.expire(at: 5)
        #expect(playback.active == nil)
    }

    @Test func unassignedGestureDoesNotPlayAndIncompatiblePreviewDoesNotReplaceAnimation() {
        var playback = enabledPlayback()
        feed(.thumbsDown, to: &playback, startingAt: 1)
        #expect(playback.active == nil)
        feed(.peace, to: &playback, startingAt: 2)
        #expect(playback.active?.reaction == .bunnyPeek)
        playback.preview(.bunnyPeek, for: .peace, at: 2)
        playback.preview(.tinyLove, for: .thumbsDown, at: 2.1)
        #expect(playback.active?.reaction == .bunnyPeek)
    }

    @Test func confirmedGestureUsesItsStoredAssignmentAndAnchor() {
        var playback = enabledPlayback()
        playback.configuration.assign(.pawFive, to: .doubleOpenPalm)
        feed(.doubleOpenPalm, to: &playback, startingAt: 1)
        #expect(playback.active?.reaction == .pawFive)
        #expect(playback.active?.anchor == CGPoint(x: 0.3, y: 0.4))
    }

    @Test func holdingGestureCannotRestartAnimationAfterItExpires() {
        var playback = enabledPlayback()
        feed(.peace, to: &playback, startingAt: 1, count: 60)
        #expect(playback.active == nil)
        for index in 0..<6 { playback.observe(nil, at: 7 + Double(index) / 10) }
        feed(.peace, to: &playback, startingAt: 8)
        #expect(playback.active?.reaction == .bunnyPeek)
    }

    @Test func delayedObservationDoesNotCancelNewManualPreview() {
        var playback = enabledPlayback()
        playback.preview(.pawFive, for: .openPalm, at: 10)
        playback.observe(GestureObservation(gesture: .peace, anchor: .zero), at: 9.9)
        #expect(playback.active?.reaction == .pawFive)
        playback.expire(at: 10.1)
        #expect(playback.active?.reaction == .pawFive)
    }

    @Test func changingAssignmentOrDisablingClearsPendingHoldAndActiveReaction() {
        var playback = enabledPlayback()
        feed(.peace, to: &playback, startingAt: 1, count: 4)
        playback.configuration.assign(nil, to: .peace)
        feed(.peace, to: &playback, startingAt: 1.4)
        #expect(playback.active == nil)
        playback.preview(.pawFive, for: .openPalm, at: 3)
        playback.configuration.enabled = false
        #expect(playback.active == nil)
    }

    private func enabledPlayback() -> GestureReactionPlayback {
        var playback = GestureReactionPlayback()
        playback.configuration.enabled = true
        return playback
    }

    private func feed(_ gesture: GestureKind, to playback: inout GestureReactionPlayback,
                      startingAt start: Double, count: Int = 10) {
        for index in 0..<count {
            playback.observe(GestureObservation(gesture: gesture, anchor: CGPoint(x: 0.3, y: 0.4)),
                             at: start + Double(index) / 10)
        }
    }
}
