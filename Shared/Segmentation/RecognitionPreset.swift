enum RecognitionPreset: CaseIterable, Identifiable {
    case fineCables, balancedMicrophone, videoCall, freestandingMicrophone

    var id: Self { self }

    var title: String {
        switch self {
        case .fineCables: "Mikrofon · Feine Kabel"
        case .balancedMicrophone: "Mikrofon · Ausgewogen"
        case .videoCall: "Videocall · Standard"
        case .freestandingMicrophone: "Freistehendes Mikrofon"
        }
    }

    var hint: String {
        switch self {
        case .fineCables: "Für dünne Kabel, Stecker und schmale Streben am Mikrofonarm. Die Zubehör-Erkennung nutzt bis zu 1024 Pixel Breite."
        case .balancedMicrophone: "Für Mikrofon und Arm bei regelmäßigen Videoanrufen. 768 Pixel bieten einen Mittelweg zwischen Kabeldetails und Rechenzeit."
        case .videoCall: "Für breite Mikrofonarme und knappere Rechenzeit. Die Zubehör-Erkennung nutzt bis zu 512 Pixel Breite."
        case .freestandingMicrophone: "Erkennt zusätzlich auffällige Objekte abseits der Person. Dabei können auch Gegenstände im Zimmer sichtbar bleiben."
        }
    }

    private var provider: SegmentationProvider { self == .freestandingMicrophone ? .appleObjects : .apple }
    private var mask: CustomMaskSettings { self == .freestandingMicrophone ? .microphoneSetup : .original }

    private var recognition: AppleRecognitionSettings {
        let detail: AccessoryDetail = switch self {
        case .fineCables, .freestandingMicrophone: .veryFine
        case .balancedMicrophone: .fine
        case .videoCall: .standard
        }
        return AppleRecognitionSettings(quality: .accurate, analysisWidth: 768, accessoryDetail: detail)
    }

    func applying(to configuration: SegmentationConfiguration) -> SegmentationConfiguration {
        var result = configuration
        result.provider = provider
        result.appleSettings = recognition
        if provider == .apple { result.appleAccessories = AppleAccessorySelection() }
        result.maskSettings = mask
        return result
    }

    static func matching(_ configuration: SegmentationConfiguration) -> Self? {
        allCases.first {
            configuration.provider == $0.provider && configuration.appleSettings == $0.recognition
                && configuration.maskSettings == $0.mask
                && ($0.provider != .apple || configuration.appleAccessories.isActive)
        }
    }
}
