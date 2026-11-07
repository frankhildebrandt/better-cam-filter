import CoreMedia
import CoreVideo
import Foundation

enum VideoBuffers {
    static func makePool(configuration: OutputConfiguration = OutputConfiguration()) throws -> CVPixelBufferPool {
        var pool: CVPixelBufferPool?
        let attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: configuration.width,
            kCVPixelBufferHeightKey as String: configuration.height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        try check(CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool))
        guard let pool else { throw VideoError.allocation }
        return pool
    }

    static func makePixelBuffer(from pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let limits = [kCVPixelBufferPoolAllocationThresholdKey: 8] as CFDictionary
        try check(CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, limits, &buffer))
        guard let buffer else { throw VideoError.allocation }
        return buffer
    }

    static func makeSampleBuffer(_ buffer: CVPixelBuffer, at time: CMTime,
                                 duration: CMTime = CameraConfiguration.frameDuration) throws -> CMSampleBuffer {
        var format: CMVideoFormatDescription?
        try check(CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format
        ))
        guard let format else { throw VideoError.allocation }
        var timing = CMSampleTimingInfo(duration: duration,
                                        presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        try check(CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: buffer, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sample
        ))
        guard let sample else { throw VideoError.allocation }
        return sample
    }

    static func check(_ status: OSStatus) throws {
        guard status == noErr else { throw VideoError.status(status) }
    }
}

enum VideoError: LocalizedError {
    case allocation
    case status(OSStatus)
    case segmentation
    case unsupportedOutput

    var errorDescription: String? {
        switch self {
        case .allocation: "Videopuffer konnte nicht erstellt werden."
        case .status(let code): "Video-Fehler (\(code))."
        case .segmentation: "Vordergrunderkennung fehlgeschlagen. Bitte Erkennungsmodus wechseln oder den Hintergrund deaktivieren."
        case .unsupportedOutput: "Die virtuelle Kamera unterstützt dieses Ausgabeformat noch nicht. Bitte die virtuelle Kamera in den Einstellungen aktualisieren."
        }
    }
}
