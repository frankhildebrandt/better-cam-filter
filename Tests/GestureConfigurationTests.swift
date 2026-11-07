import Foundation
import Testing
@testable import BetterCamCore

struct GestureConfigurationTests {
    @Test func defaultsAssignSixReactionsAndKeepOtherGesturesUnassigned() {
        let configuration = GestureConfiguration()
        #expect(!configuration.enabled)
        #expect(GestureKind.allCases.compactMap { configuration.reaction(for: $0) }.count == 6)
        #expect(configuration.reaction(for: .peace) == .bunnyPeek)
        #expect(configuration.reaction(for: .thumbsUp) == .goodBean)
        #expect(configuration.reaction(for: .openPalm) == .pawFive)
        #expect(configuration.reaction(for: .heartHands) == .lovePuff)
        #expect(configuration.reaction(for: .doubleOpenPalm) == .rainbowYay)
        #expect(configuration.reaction(for: .fingerHeart) == .tinyLove)
        #expect(configuration.reaction(for: .closedFist) == nil)
    }

    @Test func catalogCompatibilityAndAvailableChoicesAgree() {
        for gesture in GestureKind.allCases {
            #expect(gesture.availableReactions == ReactionKind.allCases.filter { $0.compatibleGestures.contains(gesture) })
        }
        #expect(GestureKind.doublePeace.availableReactions == [.bunnyPeek, .rainbowYay])
        #expect(GestureKind.thumbsDown.availableReactions.isEmpty)
        #expect(ReactionKind.allCases.allSatisfy { $0.duration == 3 })
    }

    @Test func assignmentsAndExplicitlyUnassignedDefaultsSurvivePersistence() throws {
        var configuration = GestureConfiguration()
        configuration.enabled = true
        configuration.assign(nil, to: .peace)
        configuration.assign(.rainbowYay, to: .doublePeace)
        configuration.assign(.pawFive, to: .doubleOpenPalm)
        let restored = try JSONDecoder().decode(GestureConfiguration.self, from: JSONEncoder().encode(configuration))
        #expect(restored == configuration)
        #expect(restored.reaction(for: .peace) == nil)
        #expect(restored.reaction(for: .doublePeace) == .rainbowYay)
    }

    @Test func incompatibleAssignmentsAreNeverStored() {
        var configuration = GestureConfiguration()
        configuration.assign(.tinyLove, to: .peace)
        configuration.assign(.goodBean, to: .thumbsDown)
        #expect(configuration.reaction(for: .peace) == .bunnyPeek)
        #expect(configuration.reaction(for: .thumbsDown) == nil)
    }

    @Test func decodingPreservesValidNeighborsOfFutureOrMalformedAssignments() throws {
        let json = #"{"enabled":true,"assignments":{"peace":"rainbowYay","thumbsUp":"goodBean","futureGesture":"futureReaction","openPalm":"futureReaction","fingerHeart":42,"heartHands":null,"doublePeace":"bunnyPeek"}}"#
        let configuration = try JSONDecoder().decode(GestureConfiguration.self, from: Data(json.utf8))
        #expect(configuration.enabled)
        #expect(configuration.reaction(for: .thumbsUp) == .goodBean)
        #expect(configuration.reaction(for: .doublePeace) == .bunnyPeek)
        #expect(configuration.reaction(for: .peace) == nil)
        #expect(configuration.reaction(for: .openPalm) == nil)
        #expect(configuration.reaction(for: .fingerHeart) == nil)
        #expect(configuration.reaction(for: .heartHands) == nil)
        #expect(try JSONDecoder().decode(GestureConfiguration.self, from: Data("{}".utf8)) == GestureConfiguration())
    }
}
