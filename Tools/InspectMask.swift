import CoreImage
import Foundation
import ImageIO

/// Reproduce mask changes from a local image, without opening a camera or uploading pixels.
@main
enum InspectMask {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 || arguments.count == 7 else {
            print("Usage: inspect-mask IMAGE OUTPUT_DIRECTORY [CROP_X CROP_Y CROP_WIDTH CROP_HEIGHT]")
            return
        }
        let url = URL(fileURLWithPath: arguments[1])
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              var bitmap = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw VideoError.allocation }
        if arguments.count == 7 {
            let values = try arguments[3...6].map { value -> Double in
                guard let number = Double(value) else { throw VideoError.status(-50) }
                return number
            }
            guard let crop = bitmap.cropping(to: CGRect(x: values[0], y: values[1], width: values[2], height: values[3]))
            else { throw VideoError.status(-50) }
            bitmap = crop
        }
        let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = CIContext()
        let image = FrameComposition.aspectFill(CIImage(cgImage: bitmap), in: CameraConfiguration.bounds)
        let baseline = try ForegroundSegmenter().mask(for: image)
        let refiner = AccessoryMaskRefiner(context: context)
        var refined = baseline
        for frame in 0..<6 {
            let start = ProcessInfo.processInfo.systemUptime
            refined = refiner.refine(mask: baseline, image: image, time: Double(frame) / 30)
            _ = context.createCGImage(refined, from: image.extent)
            print("Accessory refinement: \(Int((ProcessInfo.processInfo.systemUptime - start) * 1000)) ms")
        }
        let background = CIImage(color: CIColor(red: 0.12, green: 0.36, blue: 0.38)).cropped(to: image.extent)
        for (name, output) in [
            ("before", FrameComposition.replaceBackground(foreground: image, background: background, mask: baseline)),
            ("after", FrameComposition.replaceBackground(foreground: image, background: background, mask: refined)),
            ("mask", refined)
        ] {
            try context.writePNGRepresentation(of: output, to: directory.appendingPathComponent(name + ".png"),
                                               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        }
        print("Saved before.png, after.png and mask.png in \(directory.path)")
    }
}
