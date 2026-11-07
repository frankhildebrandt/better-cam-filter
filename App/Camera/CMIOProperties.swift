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
}
