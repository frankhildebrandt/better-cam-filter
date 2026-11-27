import Testing
@testable import BetterCamCore

struct AccessoryMaterialTests {
    @Test func integerClassificationMatchesFloatingPointReference() {
        var mismatches = [(Int, Int, Int)]()
        for red in stride(from: 0, through: 255, by: 3) {
            for green in stride(from: 0, through: 255, by: 3) {
                for blue in stride(from: 0, through: 255, by: 3) {
                    let rgba: [UInt8] = [UInt8(red), UInt8(green), UInt8(blue), 255]
                    if AccessoryMaterial.category(rgba, at: 0) != reference(red, green, blue) {
                        mismatches.append((red, green, blue))
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    @Test func thresholdNeighborsMatchFloatingPointReference() {
        // Luma 0.33/0.10/0.76 and chroma 0.14/0.22 boundaries, probed with gray and tinted samples.
        for base in [24, 25, 26, 83, 84, 85, 193, 194, 195] {
            for tint in [0, 34, 35, 36, 55, 56, 57, 58] where base + tint <= 255 {
                for rgb in [(base + tint, base, base), (base, base + tint, base), (base, base, base + tint)] {
                    let rgba: [UInt8] = [UInt8(rgb.0), UInt8(rgb.1), UInt8(rgb.2), 255]
                    #expect(AccessoryMaterial.category(rgba, at: 0) == reference(rgb.0, rgb.1, rgb.2), "\(rgb)")
                }
            }
        }
    }

    /// The original floating-point classification the integer version must reproduce.
    private func reference(_ red: Int, _ green: Int, _ blue: Int) -> UInt8 {
        let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
        let high = max(r, g, b), low = min(r, g, b)
        let chroma = high - low
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (luma < 0.33 && chroma < 0.22) || luma < 0.10 { return 1 }
        if chroma < 0.14 { return luma < 0.76 ? 14 : 15 }
        guard chroma > 0.22, chroma / max(high, 0.001) > 0.4 else { return 0 }
        let hue: Double
        if high == r { hue = ((g - b) / chroma).truncatingRemainder(dividingBy: 6) }
        else if high == g { hue = (b - r) / chroma + 2 }
        else { hue = (r - g) / chroma + 4 }
        return UInt8(Int(((hue + 6) * 2).rounded(.down)) % 12 + 2)
    }
}
