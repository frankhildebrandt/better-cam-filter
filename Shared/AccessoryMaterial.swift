/// Appearance classes that let accessory components grow only through one material at a time.
enum AccessoryMaterial {
    static let dark: UInt8 = 1
    // Labels 2...13 are the cable hue bins.
    static let midtone: UInt8 = 14
    static let highlight: UInt8 = 15

    /// Classify one RGBA sample with integer thresholds; only saturated colors need a floating-point hue.
    /// Luma is scaled by 255 × 10 000 and chroma by 255, so every comparison stays exact.
    static func category(_ rgba: [UInt8], at offset: Int) -> UInt8 {
        let r = Int(rgba[offset]), g = Int(rgba[offset + 1]), b = Int(rgba[offset + 2])
        let high = max(r, g, b), chroma = high - min(r, g, b)
        let luma = 2126 * r + 7152 * g + 722 * b
        if (luma < 841_500 && chroma <= 56) || luma < 255_000 { return dark }
        if chroma <= 35 { return luma < 1_938_000 ? midtone : highlight }
        guard chroma >= 57, 5 * chroma > 2 * high else { return 0 }
        return hueBin(r, g, b, high: high, chroma: chroma)
    }

    /// Twelve 30° hue bins, offset by two so they never collide with dark.
    private static func hueBin(_ r: Int, _ g: Int, _ b: Int, high: Int, chroma: Int) -> UInt8 {
        let c = Double(chroma)
        let hue: Double
        if high == r { hue = (Double(g - b) / c).truncatingRemainder(dividingBy: 6) }
        else if high == g { hue = Double(b - r) / c + 2 }
        else { hue = Double(r - g) / c + 4 }
        return UInt8(Int(((hue + 6) * 2).rounded(.down)) % 12 + 2)
    }
}
