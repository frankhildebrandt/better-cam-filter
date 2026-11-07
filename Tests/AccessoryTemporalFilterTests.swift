import Testing
@testable import BetterCamCore

struct AccessoryTemporalFilterTests {
    private let width = 10
    private let height = 10
    private let accessory = 56

    @Test func oneFrameBackgroundFlashIsNeverAdmitted() {
        let filter = AccessoryTemporalFilter()
        #expect(frame(filter, candidate: false, time: 0)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.04)[accessory] == 0)
        #expect(frame(filter, candidate: false, time: 0.08)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.12)[accessory] == 0)
        #expect(frame(filter, candidate: false, time: 0.16)[accessory] == 0)
    }

    @Test func stableAccessoryRequiresContinuousEvidence() {
        let filter = AccessoryTemporalFilter()
        #expect(frame(filter, candidate: true, time: 0)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.05)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.11)[accessory] == 255)
    }

    @Test func twoSparseFramesAreNotEnoughForConfirmation() {
        let filter = AccessoryTemporalFilter()
        #expect(frame(filter, candidate: true, time: 0)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.12)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.16)[accessory] == 255)
    }

    @Test func cameraMotionAndDimensionChangesResetOldConfirmations() {
        let filter = confirmedFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[0] = 255
        let rgba = [UInt8](repeating: 80, count: width * height * 4)
        let empty = [UInt8](repeating: 0, count: width * height)
        #expect(filter.filter(empty, person: person, rgba: rgba, width: width, height: height, time: 0.15)[accessory] == 0)
        var changed = empty
        changed[accessory] = 255
        #expect(filter.filter(changed, person: person, rgba: rgba, width: 20, height: 5, time: 0.18)[accessory] == 0)
    }

    @Test func sceneChangeResetsEvenWhenAccessoryPixelRetainsItsColor() {
        let filter = confirmedFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var additions = [UInt8](repeating: 0, count: width * height)
        additions[accessory] = 255
        var rgba = [UInt8](repeating: 200, count: width * height * 4)
        for channel in 0..<3 { rgba[accessory * 4 + channel] = 50 }
        #expect(filter.filter(additions, person: person, rgba: rgba, width: width, height: height, time: 0.15)[accessory] == 0)
    }

    @Test func shortDropoutDoesNotToggleAConfirmedAccessory() {
        let filter = confirmedFilter()
        #expect(frame(filter, candidate: false, time: 0.15)[accessory] == 255)
        #expect(frame(filter, candidate: true, time: 0.18)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.22)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.30)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.43)[accessory] == 0)
    }

    @Test func revealedBrightBackgroundNeedsRepeatedNegativeEvidence() {
        let filter = confirmedFilter()
        #expect(frame(filter, candidate: false, time: 0.15, color: 255)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.19, color: 255)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.23, color: 255)[accessory] == 0)
    }

    @Test func losingPersonAnchorClearsAccessories() {
        let filter = confirmedFilter()
        #expect(frame(filter, candidate: true, time: 0.15, personPresent: false)[accessory] == 0)
        #expect(frame(filter, candidate: true, time: 0.18)[accessory] == 0)
    }

    @Test func resetAndTimeGapsCannotReuseConfirmedPixels() {
        let filter = confirmedFilter()
        filter.reset()
        #expect(frame(filter, candidate: true, time: 0.15)[accessory] == 0)
        _ = frame(filter, candidate: true, time: 0.26)
        #expect(frame(filter, candidate: true, time: 1)[accessory] == 0)
    }

    @Test func personAlphaAloneDoesNotCreateAccessoryHistory() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[accessory] = 255
        let rgba = [UInt8](repeating: 50, count: width * height * 4)
        let additions = [UInt8](repeating: 0, count: width * height)
        for time in [0.0, 0.05, 0.11, 0.15] {
            let result = filter.filter(additions, person: person, rgba: rgba, width: width, height: height, time: time)
            #expect(result[accessory] == 0)
        }
        #expect(frame(filter, candidate: false, time: 0.18)[accessory] == 0)
    }

    @Test func confirmedMicSurvivesRepeatedSemanticCoverageAndRelease() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var evidence = person
        evidence[accessory] = 255
        let rgba = [UInt8](repeating: 50, count: width * height * 4)
        for index in 0..<12 {
            person[accessory] = index < 5 || index.isMultiple(of: 2) ? 255 : 0
            let overlay = filter.filter(evidence, person: person, rgba: rgba,
                                        width: width, height: height, time: Double(index) * 0.04)
            if index >= 5 { #expect(max(person[accessory], overlay[accessory]) == 255) }
        }
    }

    @Test func positiveEvidenceSurvivesLightingDriftWithoutReconfirmationHoles() {
        let filter = confirmedFilter()
        for index in 0..<12 {
            #expect(frame(filter, candidate: true, time: 0.15 + Double(index) * 0.04,
                          color: UInt8(50 + index * 5))[accessory] == 255)
        }
        #expect(frame(filter, candidate: false, time: 0.63, color: 105)[accessory] == 255)
    }

    @Test func oneColorOutlierCannotRemoveAPositivelyRecognizedMic() {
        let filter = confirmedFilter()
        #expect(frame(filter, candidate: true, time: 0.15, color: 115)[accessory] == 255)
        #expect(frame(filter, candidate: true, time: 0.19, color: 50)[accessory] == 255)
    }

    @Test func threeMissingFramesDoNotForceStartupConfirmationOnRecovery() {
        let filter = confirmedFilter()
        for time in [0.15, 0.19, 0.23] {
            #expect(frame(filter, candidate: false, time: time)[accessory] == 255)
        }
        #expect(frame(filter, candidate: true, time: 0.27)[accessory] == 255)
        #expect(frame(filter, candidate: true, time: 0.31)[accessory] == 255)
    }

    @Test func movingKnownComponentDoesNotDelayItsNewPixels() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var evidence = [UInt8](repeating: 0, count: width * height)
        evidence[56] = 255
        evidence[66] = 255
        let rgba = [UInt8](repeating: 50, count: width * height * 4)
        for time in [0.0, 0.05, 0.11] {
            _ = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: time)
        }
        evidence[57] = 255
        evidence[67] = 255
        let moved = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.15)
        #expect(moved[57] == 255)
        #expect(moved[67] == 255)
        evidence[59] = 255 // Detached one-frame noise must not inherit an object's confirmation.
        let noise = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.19)
        #expect(noise[59] == 0)
    }

    @Test func personMovementDoesNotCountAsABackgroundSceneChange() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        for pixel in 0..<60 { person[pixel] = 255 }
        var evidence = [UInt8](repeating: 0, count: width * height)
        evidence[66] = 255
        var rgba = [UInt8](repeating: 50, count: width * height * 4)
        for time in [0.0, 0.05, 0.11] {
            _ = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: time)
        }
        for pixel in 0..<60 {
            for channel in 0..<3 { rgba[pixel * 4 + channel] = 220 }
        }
        let moved = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.15)
        #expect(moved[66] == 255)
    }

    @Test func newlyConnectedLargeRegionCannotBorrowASmallObjectsConfirmation() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var evidence = [UInt8](repeating: 0, count: width * height)
        evidence[56] = 255
        evidence[66] = 255
        let rgba = [UInt8](repeating: 50, count: width * height * 4)
        for time in [0.0, 0.05, 0.11] {
            _ = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: time)
        }
        for pixel in [57, 58, 59, 67, 68, 69, 76, 77, 78, 79] { evidence[pixel] = 255 }
        let result = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.15)
        #expect(result[57] == 0)
        #expect(result[56] == 255)
    }

    @Test func oneBrightOutlierDuringAnExistingDropoutCannotTriggerFastRemoval() {
        let filter = confirmedFilter()
        #expect(frame(filter, candidate: false, time: 0.15)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.23, color: 255)[accessory] == 255)
        #expect(frame(filter, candidate: false, time: 0.27)[accessory] == 255)
        #expect(frame(filter, candidate: true, time: 0.31)[accessory] == 255)
    }

    @Test func newConnectedPixelsMustMatchTheKnownObjectsAppearance() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var evidence = [UInt8](repeating: 0, count: width * height)
        evidence[56] = 255
        evidence[66] = 255
        var rgba = [UInt8](repeating: 20, count: width * height * 4)
        for time in [0.0, 0.05, 0.11] {
            _ = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: time)
        }
        for pixel in [57, 67] {
            evidence[pixel] = 255
            for channel in 0..<3 { rgba[pixel * 4 + channel] = 80 }
        }
        let result = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.15)
        #expect(result[56] == 255)
        #expect(result[57] == 0)
        #expect(result[67] == 0)
    }

    @Test func motionConfirmationCannotSpreadBeyondItsBoundedEdge() {
        let filter = AccessoryTemporalFilter()
        var person = [UInt8](repeating: 0, count: width * height)
        person[55] = 255
        var evidence = [UInt8](repeating: 0, count: width * height)
        evidence[56] = 255
        evidence[66] = 255
        let rgba = [UInt8](repeating: 50, count: width * height * 4)
        for time in [0.0, 0.05, 0.11] {
            _ = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: time)
        }
        for pixel in [57, 58, 59] { evidence[pixel] = 255 }
        let result = filter.filter(evidence, person: person, rgba: rgba, width: width, height: height, time: 0.15)
        #expect(result[57] == 255)
        #expect(result[58] == 255)
        #expect(result[59] == 0)
    }

    private func confirmedFilter() -> AccessoryTemporalFilter {
        let filter = AccessoryTemporalFilter()
        _ = frame(filter, candidate: true, time: 0)
        _ = frame(filter, candidate: true, time: 0.05)
        _ = frame(filter, candidate: true, time: 0.11)
        return filter
    }

    private func frame(_ filter: AccessoryTemporalFilter, candidate: Bool, time: Double,
                       color: UInt8 = 50, personPresent: Bool = true) -> [UInt8] {
        var additions = [UInt8](repeating: 0, count: width * height)
        var person = additions
        if personPresent { person[55] = 255 }
        if candidate { additions[accessory] = 255 }
        var rgba = [UInt8](repeating: 80, count: width * height * 4)
        for channel in 0..<3 { rgba[accessory * 4 + channel] = color }
        return filter.filter(additions, person: person, rgba: rgba, width: width, height: height, time: time)
    }
}
