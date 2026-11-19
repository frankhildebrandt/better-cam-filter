import SwiftUI
import Vision

struct RecognitionControls: View {
    @ObservedObject var settings: SegmentationSettingsModel

    var body: some View {
        if settings.configuration.provider != .custom {
            Section {
                if settings.configuration.provider == .apple || settings.configuration.maskSettings.personSupport {
                    Picker("Qualität", selection: appleValue(\.quality)) {
                        ForEach(RecognitionQuality.allCases) { Text($0.title).tag($0) }
                    }
                }
                Picker("Analyseauflösung", selection: appleValue(\.analysisWidth)) {
                    ForEach([256, 384, 512, 768, 1024, 1536, 1920, 2560, 3840], id: \.self) { width in
                        Text("\(width) Pixel breit").tag(width)
                    }
                    Text("Volle Ausgabeauflösung").tag(0)
                }
                if settings.configuration.provider == .apple || settings.configuration.maskSettings.personSupport {
                    Picker("Vision-Version", selection: appleValue(\.revision)) {
                        Text("Automatisch").tag(0)
                        ForEach(Array(VNGeneratePersonSegmentationRequest.supportedRevisions), id: \.self) { revision in
                            Text("Version \(revision)").tag(revision)
                        }
                    }
                }
                Toggle("Hintergrundverarbeitung bevorzugen", isOn: appleValue(\.preferBackgroundProcessing))
            } header: {
                Text("Apple Vision")
            } footer: {
                Text("Höhere Qualität und Analyseauflösung benötigen mehr Rechenzeit. Die Analyseauflösung ist eine Obergrenze; kleinere Kamerabilder werden nicht hochskaliert. Hintergrundverarbeitung priorisiert andere Apps und kann die Bildrate senken.")
            }
            .disabled(settings.isBusy)
        } else {
            Section {
                Picker("Recheneinheiten", selection: inferenceValue(\.computeUnits)) {
                    ForEach(ModelComputeUnits.allCases) { Text($0.title).tag($0) }
                }
                Picker("Bildeingang", selection: inferenceValue(\.inputScaling)) {
                    ForEach(ModelInputScaling.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Modellausführung")
            } footer: {
                Text("Gilt nur für dieses Modell. Die Eingangsgröße ist im Modell festgelegt. Einpassen erhält das vollständige Bild mit schwarzen Rändern; Ausfüllen schneidet die Bildränder ab. Außerhalb des beschnittenen Bereichs liefert das Modell keine Maske. Die tatsächliche Beschleunigung hängt von Mac und Modell ab.")
            }
            .disabled(settings.isBusy)
            if settings.configuration.maskSettings.personSupport {
                DisclosureGroup("Zusätzliche Apple-Erkennung") {
                    Picker("Qualität", selection: appleValue(\.quality)) {
                        ForEach(RecognitionQuality.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Analyseauflösung", selection: appleValue(\.analysisWidth)) {
                        ForEach([256, 384, 512, 768, 1024, 1536, 1920, 2560, 3840], id: \.self) { width in
                            Text("\(width) Pixel breit").tag(width)
                        }
                        Text("Volle Ausgabeauflösung").tag(0)
                    }
                    Picker("Vision-Version", selection: appleValue(\.revision)) {
                        Text("Automatisch").tag(0)
                        ForEach(Array(VNGeneratePersonSegmentationRequest.supportedRevisions), id: \.self) { revision in
                            Text("Version \(revision)").tag(revision)
                        }
                    }
                    Toggle("Hintergrundverarbeitung bevorzugen", isOn: appleValue(\.preferBackgroundProcessing))
                }
                .disabled(settings.isBusy)
            }
        }
    }

    private func appleValue<Value>(_ path: WritableKeyPath<AppleRecognitionSettings, Value>) -> Binding<Value> {
        Binding(get: { settings.configuration.appleSettings[keyPath: path] }, set: { value in
            var updated = settings.configuration.appleSettings
            updated[keyPath: path] = value
            settings.updateAppleSettings(updated)
        })
    }

    private func inferenceValue<Value>(_ path: WritableKeyPath<ModelInferenceSettings, Value>) -> Binding<Value> {
        Binding(get: { settings.configuration.inferenceSettings[keyPath: path] }, set: { value in
            var updated = settings.configuration.inferenceSettings
            updated[keyPath: path] = value
            settings.updateInferenceSettings(updated)
        })
    }
}

struct AccessoryDetailPicker: View {
    @ObservedObject var settings: SegmentationSettingsModel

    var body: some View {
        Picker("Zubehör-Auflösung", selection: Binding(
            get: { settings.configuration.appleSettings.accessoryDetail },
            set: { detail in
                var apple = settings.configuration.appleSettings
                apple.accessoryDetail = detail
                settings.updateAppleSettings(apple)
            }
        )) {
            ForEach(AccessoryDetail.allCases, id: \.self) { detail in
                Text("\(detail.rawValue) Pixel breit").tag(detail)
            }
        }
        .disabled(settings.isBusy)
        Text("Eine höhere Auflösung erfasst feinere Kabel und kann die Bildrate senken. Die Einstellung gilt für alle Modelle mit Zubehör-Erkennung.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct CustomMaskControls: View {
    @ObservedObject var settings: SegmentationSettingsModel

    private var mask: CustomMaskSettings { settings.configuration.maskSettings }
    private var presets: [(id: String, title: String, value: CustomMaskSettings)] {
        var values: [(id: String, title: String, value: CustomMaskSettings)] = [
            ("stabilized", "Nur stabilisieren", .stabilized),
            ("balanced", "Ausgewogen", .balanced), ("detailed", "Mehr Vordergrund", .detailed),
            ("clean", "Saubere Kanten", .cleanEdges), ("original", "Unverändert", .original)
        ]
        if settings.configuration.provider != .apple {
            values.insert(("mic", "Mikrofon, Arm & Kabel", .microphoneSetup), at: 0)
        }
        return values
    }

    var body: some View {
        Section {
            Picker("Vorgabe", selection: preset) {
                ForEach(presets, id: \.id) { Text($0.title).tag($0.id) }
                Text("Benutzerdefiniert").tag("custom").disabled(true)
            }
            Toggle("Maske nachbearbeiten", isOn: value(\.enabled))
            if mask.enabled {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Erkennungsschwelle", value: mask.threshold.formatted(.percent.precision(.fractionLength(0))))
                    Slider(value: value(\.threshold), in: 0.05...0.95, step: 0.01).accessibilityLabel("Erkennungsschwelle")
                    hint("Niedriger behält mehr Arme und Zubehör, kann aber auch mehr Raum erhalten.")
                }
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Übergangsbreite", value: mask.transition.formatted(.percent.precision(.fractionLength(0))))
                    Slider(value: value(\.transition), in: 0.02...1, step: 0.01).accessibilityLabel("Übergangsbreite")
                    hint("Schmaler macht erkannte Flächen deckender. Breiter erzeugt weichere, durchsichtigere Übergänge.")
                }
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Kantenkorrektur", value: "\(mask.edgeInset.formatted(.number.precision(.fractionLength(1)))) px")
                    Slider(value: value(\.edgeInset), in: -4...6, step: 0.5).accessibilityLabel("Kantenkorrektur")
                    hint("Positiv verkleinert die Maske gegen helle Säume. Negativ erweitert sie. Pixel beziehen sich auf Full HD.")
                }
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Flackern reduzieren", value: mask.temporalStrength.formatted(.percent.precision(.fractionLength(0))))
                    Slider(value: value(\.temporalStrength), in: 0...1, step: 0.1).accessibilityLabel("Flackern reduzieren")
                    hint("Überbrückt kurze Aussetzer bei gleichem Bildinhalt. Bei nachziehenden Konturen den Wert senken.")
                }
                if settings.configuration.provider != .apple {
                    Toggle("Person zusätzlich mit Apple erkennen", isOn: value(\.personSupport))
                    hint("Kann fehlende Körperbereiche ergänzen und benötigt zusätzliche Rechenzeit. Die Objektmaske des gewählten Modells bleibt erhalten.")
                    if mask.personSupport {
                        Toggle("Mikrofon, Arm & Kabel ergänzen", isOn: value(\.accessorySupport))
                        if mask.accessorySupport { AccessoryDetailPicker(settings: settings) }
                    }
                }
            }
        } header: {
            Text("Maske optimieren")
        } footer: {
            Text("Die Einstellungen gelten für das gewählte Modell. Bei dauerhaft fehlenden Teilen kannst du im Kamerabild Schutzbereiche markieren.")
        }
        .disabled(settings.isBusy)
    }

    private func hint(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(.secondary) }

    private func value<Value>(_ path: WritableKeyPath<CustomMaskSettings, Value>) -> Binding<Value> {
        Binding(get: { mask[keyPath: path] }, set: { newValue in
            var updated = mask
            updated[keyPath: path] = newValue
            settings.updateMaskSettings(updated)
        })
    }

    private var preset: Binding<String> {
        Binding(get: { !mask.enabled ? "original" : presets.first(where: { $0.value == mask })?.id ?? "custom" }, set: { id in
            if let selected = presets.first(where: { $0.id == id }) { settings.updateMaskSettings(selected.value) }
        })
    }
}
