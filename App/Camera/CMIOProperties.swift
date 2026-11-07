import CoreMediaIO
import Foundation

enum CMIOProperties {
    static func address(_ selector: CMIOObjectPropertySelector) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(mSelector: selector, mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                  mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    }

    static func objects(_ object: CMIOObjectID, selector: CMIOObjectPropertySelector) throws -> [CMIOObjectID] {
        var property = address(selector)
        var size: UInt32 = 0
        try VideoBuffers.check(CMIOObjectGetPropertyDataSize(object, &property, 0, nil, &size))
        var values = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        try values.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            try VideoBuffers.check(CMIOObjectGetPropertyData(object, &property, 0, nil, size, &size, base))
        }
        return values
    }

    static func string(_ object: CMIOObjectID, selector: CMIOObjectPropertySelector) throws -> String {
        var property = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try VideoBuffers.check(CMIOObjectGetPropertyData(object, &property, 0, nil, size, &size, &value))
        guard let value else { throw VideoError.status(-50) }
        return value.takeRetainedValue() as String
    }

    static func uint32(_ object: CMIOObjectID, selector: CMIOObjectPropertySelector) throws -> UInt32 {
        var property = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try VideoBuffers.check(CMIOObjectGetPropertyData(object, &property, 0, nil, size, &size, &value))
        return value
    }

    static func configure(_ stream: CMIOStreamID, for configuration: OutputConfiguration) throws {
        var property = address(CMIOObjectPropertySelector(kCMIOStreamPropertyFormatDescriptions))
        var descriptions: Unmanaged<CFArray>?
        var size = UInt32(MemoryLayout<Unmanaged<CFArray>?>.size)
        try VideoBuffers.check(CMIOObjectGetPropertyData(stream, &property, 0, nil, size, &size, &descriptions))
        guard let formats = descriptions?.takeRetainedValue() as? [CMFormatDescription],
              let format = formats.first(where: {
                  let dimensions = CMVideoFormatDescriptionGetDimensions($0)
                  return dimensions.width == configuration.width && dimensions.height == configuration.height
              }) else { throw VideoError.unsupportedOutput }
        var selected = Unmanaged.passUnretained(format).toOpaque()
        property = address(CMIOObjectPropertySelector(kCMIOStreamPropertyFormatDescription))
        try VideoBuffers.check(CMIOObjectSetPropertyData(stream, &property, 0, nil,
                                                       UInt32(MemoryLayout<UnsafeMutableRawPointer>.size), &selected))
        var rate = Double(configuration.frameRate)
        property = address(CMIOObjectPropertySelector(kCMIOStreamPropertyFrameRate))
        try VideoBuffers.check(CMIOObjectSetPropertyData(stream, &property, 0, nil,
                                                       UInt32(MemoryLayout<Double>.size), &rate))
    }
}
