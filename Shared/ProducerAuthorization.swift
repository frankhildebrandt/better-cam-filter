import Foundation
import Security

/// Validates the running producer against the extension's own Apple signing team.
struct ProducerAuthorization {
    private let requirement: SecRequirement?
    let teamIdentifier: String?

    init(teamIdentifier: String? = ProducerAuthorization.currentTeamIdentifier()) {
        self.teamIdentifier = teamIdentifier
        guard let teamIdentifier, teamIdentifier.utf8.count == 10,
              teamIdentifier.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }) else {
            requirement = nil
            return
        }
        let expression = "identifier \"de.bettercam.app\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(expression as CFString, [], &requirement) == errSecSuccess else {
            self.requirement = nil
            return
        }
        self.requirement = requirement
    }

    func allows(processID: pid_t) -> Bool {
        validationStatus(processID: processID) == errSecSuccess
    }

    func validationStatus(processID: pid_t) -> OSStatus {
        guard processID > 0 else { return errSecParam }
        guard let requirement else { return errSecAuthFailed }
        var code: SecCode?
        // Kernel-backed code lookup avoids opening another process's executable from the CMIO sandbox.
        let attributes: CFDictionary = [
            kSecGuestAttributePid as String: processID,
            kSecGuestAttributeDynamicCode as String: true
        ] as CFDictionary
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        guard status == errSecSuccess else { return status }
        guard let code else { return errSecAuthFailed }
        return SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement)
    }

    private static func currentTeamIdentifier() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                           &information) == errSecSuccess else { return nil }
        return (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
