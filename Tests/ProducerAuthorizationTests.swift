import Foundation
import Testing
@testable import BetterCamCore

struct ProducerAuthorizationTests {
    @Test func absentOrInvalidTeamFailsClosed() {
        for team in [nil, "", "invalid", "\" or true", "4r24354z88"] as [String?] {
            #expect(!ProducerAuthorization(teamIdentifier: team).allows(processID: getpid()))
        }
    }

    @Test func invalidAndUnrelatedProcessesAreRejected() {
        let authorization = ProducerAuthorization(teamIdentifier: "4R24354Z88")
        #expect(!authorization.allows(processID: 0))
        #expect(!authorization.allows(processID: -1))
        #expect(!authorization.allows(processID: pid_t.max))
        #expect(!authorization.allows(processID: getpid()))
        #expect(!authorization.allows(processID: 1))
    }

    @Test func anotherTeamCannotAuthorizeThisProcess() {
        #expect(!ProducerAuthorization(teamIdentifier: "AAAAAAAAAA").allows(processID: getpid()))
    }
}
