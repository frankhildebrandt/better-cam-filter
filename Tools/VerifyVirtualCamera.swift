import CoreMediaIO
import Foundation

/// Checks real client delivery without saving camera images or background assets.
@main
enum VerifyVirtualCamera {
    static func main() {
        do { try receive() }
        catch {
            FileHandle.standardError.write(Data("Virtual camera check failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func receive() throws {
        let devices = try CMIOProperties.objects(CMIOObjectID(kCMIOObjectSystemObject),
            selector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        guard let device = devices.first(where: {
            (try? CMIOProperties.string($0, selector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID)))
                == CameraConfiguration.deviceID.uuidString
        }) else { throw ProbeError("BetterCam device is not available.") }
        let streams = try CMIOProperties.objects(device,
            selector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams))
        guard let stream = streams.first(where: {
            (try? CMIOProperties.uint32($0, selector: CMIOObjectPropertySelector(kCMIOStreamPropertyDirection))) == 1
        }) else { throw ProbeError("BetterCam source stream is not available.") }

        var unmanaged: Unmanaged<CMSimpleQueue>?
        try VideoBuffers.check(CMIOStreamCopyBufferQueue(stream, { _, _, _ in }, nil, &unmanaged))
        guard let queue = unmanaged?.takeRetainedValue() else { throw ProbeError("Frame queue is unavailable.") }
        try VideoBuffers.check(CMIODeviceStartStream(device, stream))
        defer {
            CMIODeviceStopStream(device, stream)
            while let pointer = CMSimpleQueueDequeue(queue) {
                Unmanaged<CMSampleBuffer>.fromOpaque(pointer).release()
            }
        }

        var count = 0
        var nonblack = 0
        let end = Date().addingTimeInterval(5)
        while Date() < end {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            while let pointer = CMSimpleQueueDequeue(queue) {
                let sample = Unmanaged<CMSampleBuffer>.fromOpaque(pointer).takeRetainedValue()
                count += 1
                if let buffer = sample.imageBuffer, brightness(of: buffer) > 192 { nonblack += 1 }
            }
        }
        print("Received frames: \(count), nonblack frames: \(nonblack)")
        guard count > 1, nonblack > 0 else {
            throw ProbeError("BetterCam did not deliver live image frames.")
        }
    }

    private static func brightness(of buffer: CVPixelBuffer) -> Int {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { return 0 }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        var sum = 0
        for y in stride(from: height / 16, to: height, by: max(1, height / 8)) {
            for x in stride(from: width / 16, to: width, by: max(1, width / 8)) {
                let offset = y * row + x * 4
                sum += Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])
            }
        }
        return sum
    }
}

private struct ProbeError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
