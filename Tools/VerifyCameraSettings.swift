import Combine
import CoreImage
import Foundation
import SwiftUI

/// Exercises the real controller and SwiftUI writeback without opening a camera.
@main
enum VerifyCameraSettings {
    @MainActor
    static func main() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.data(forKey: "outputConfiguration")
        defer {
            if let previous { defaults.set(previous, forKey: "outputConfiguration") }
            else { defaults.removeObject(forKey: "outputConfiguration") }
        }

        let camera = CameraModel()
        var changes = 0
        let observation = camera.objectWillChange.sink { changes += 1 }
        defer { observation.cancel() }
        let binding = Binding(get: { camera.outputConfiguration }, set: { camera.outputConfiguration = $0 })

        binding.frameRate.wrappedValue = 60
        precondition(camera.outputConfiguration.frameRate == 60)
        precondition(CameraModel().outputConfiguration == camera.outputConfiguration)

        for resolution in OutputResolution.allCases {
            binding.resolution.wrappedValue = resolution
            for rate in OutputConfiguration.frameRates {
                binding.frameRate.wrappedValue = rate
                precondition(camera.outputConfiguration == OutputConfiguration(resolution: resolution, frameRate: rate))
                let saved = try JSONDecoder().decode(OutputConfiguration.self,
                                                     from: defaults.data(forKey: "outputConfiguration")!)
                precondition(saved == camera.outputConfiguration)
            }
        }

        binding.frameRate.wrappedValue = -1
        precondition(camera.outputConfiguration.frameRate == 30)
        let beforeUnchangedWrite = changes
        binding.wrappedValue = binding.wrappedValue
        precondition(changes == beforeUnchangedWrite)
        precondition(changes > 0 && changes <= 26)
        print("CameraModel settings: 60 FPS, all formats, persistence, invalid rates and notifications passed.")

        verifyPreviewRendering()
        print("Preview rendering passed for headless output, individual previews and shared previews.")
        try verifyUnsegmentedFramesNeverExposeTheRoom()
        print("Background replacement drops frames that arrive before their segmentation.")
    }

    private static func verifyUnsegmentedFramesNeverExposeTheRoom() throws {
        let configuration = OutputConfiguration()
        var input: CVPixelBuffer?
        CVPixelBufferCreate(nil, configuration.width, configuration.height, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &input)
        let foreground = CIImage(cvPixelBuffer: input!)
        let mask = CIImage(color: .white).cropped(to: configuration.bounds)
        func frame(_ segmentation: Result<SegmentationAnalysis, any Error>?) -> AnalyzedFrame {
            AnalyzedFrame(input: input!, time: .zero, foreground: foreground, segmentation: segmentation)
        }
        let processor = FrameProcessor()
        processor.outputConfiguration = configuration
        let withoutBackground = try processor.process(frame(nil), keepPreviewMask: false)
        processor.background = CIImage(color: .blue).cropped(to: configuration.bounds)
        let unsegmented = try processor.process(frame(nil), keepPreviewMask: false)
        let segmented = try processor.process(frame(.success(SegmentationAnalysis(primary: mask, supportingPerson: nil))),
                                              keepPreviewMask: false)
        precondition(withoutBackground != nil && unsegmented == nil && segmented != nil)
    }

    private static func verifyPreviewRendering() {
        let bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        let output = CIImage(color: .red).cropped(to: bounds)
        let mask = CIImage(color: .white).cropped(to: bounds)
        let context = CIContext()
        let colorFrame = context.createCGImage(output, from: bounds)!
        let maskFrame = context.createCGImage(mask, from: bounds)!

        func check(_ visible: Set<PreviewSource>, alternate: CIImage?, main: CGImage?, gestures: CGImage?,
                   renderCount: Int) {
            var count = 0
            let previews = CaptureEngine.renderPreviews(for: visible, alternate: alternate, output: output) { image in
                count += 1
                precondition(image === output || image === mask)
                return image === output ? colorFrame : maskFrame
            }
            precondition(count == renderCount && previews.main === main && previews.gestures === gestures)
        }

        check([], alternate: mask, main: nil, gestures: nil, renderCount: 0)
        check([.mainWindow], alternate: nil, main: colorFrame, gestures: nil, renderCount: 1)
        check([.mainWindow], alternate: mask, main: maskFrame, gestures: nil, renderCount: 1)
        check([.gestures], alternate: mask, main: nil, gestures: colorFrame, renderCount: 1)
        check([.mainWindow, .gestures], alternate: nil, main: colorFrame, gestures: colorFrame, renderCount: 1)
        check([.mainWindow, .gestures], alternate: mask, main: maskFrame, gestures: colorFrame, renderCount: 2)
    }
}
