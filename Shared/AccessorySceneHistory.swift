/// Detect changes in the room without treating a moving person or accessory as a scene cut.
struct AccessorySceneHistory {
    private var previousImage = [UInt8]()
    private var previousPerson = [UInt8]()

    mutating func changed(rgba: [UInt8], person: [UInt8], evidence: [UInt8], confirmed: [Bool]) -> Bool {
        defer { previousImage = rgba; previousPerson = person }
        guard previousImage.count == rgba.count, previousPerson.count == person.count else { return false }
        var difference = 0
        var samples = 0
        for pixel in stride(from: 0, to: person.count, by: 4)
        where person[pixel] < 32 && previousPerson[pixel] < 32
            && evidence[pixel] <= 200 && !confirmed[pixel] {
            for channel in 0..<3 {
                difference += abs(Int(rgba[pixel * 4 + channel]) - Int(previousImage[pixel * 4 + channel]))
            }
            samples += 1
        }
        return samples >= max(4, person.count / 64) && Double(difference) / Double(samples * 3) > 35
    }
}
