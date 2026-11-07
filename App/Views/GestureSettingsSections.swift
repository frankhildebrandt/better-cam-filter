import SwiftUI

struct GestureSettingsSections: View {
    @ObservedObject var camera: CameraModel

    var body: some View {
        Section {
            Toggle("Gestenerkennung aktivieren", isOn: $camera.gestureConfiguration.enabled)
            Text("Halte eine Geste etwa 0,6 Sekunden. Eine Reaction spielt einmal ab; löse die Geste vor dem nächsten Auslösen. Erkennung und Animationen laufen lokal auf deinem Mac.")
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text("Gesten-Reactions")
        } footer: {
            Text("Die Zuordnungen werden automatisch gespeichert. Apples eigene Reactions lassen sich im macOS-Videomenü ausschalten, falls beide Effekte gleichzeitig erscheinen.")
        }

        Section("Ausprobieren") {
            HStack(alignment: .top, spacing: 16) {
                PreviewView(image: camera.outputPreview, isRunning: camera.isRunning)
                    .frame(width: 240)
                    .accessibilityLabel("Live-Vorschau der Gesten-Reactions")
                VStack(alignment: .leading, spacing: 10) {
                    Label(status, systemImage: camera.detectedGesture == nil ? "hand.raised" : "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(camera.detectedGesture == nil ? Color.secondary : .green)
                    Text("Die Testbuttons spielen die gewählte Reaction direkt im Kamera-Ausgang ab – auch bei ausgeschalteter Gestenerkennung.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !camera.isRunning {
                        Button("Kamera starten", systemImage: "play.fill") { Task { await camera.start() } }
                            .disabled(camera.isBusy || camera.selectedCameraID.isEmpty)
                    }
                }
            }
            if let error = camera.gestureError ?? camera.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
        }

        Section {
            ForEach(GestureKind.allCases) { gesture in
                GestureSlotRow(gesture: gesture, reaction: reaction(for: gesture),
                               detected: camera.detectedGesture == gesture, canTest: camera.isRunning) {
                    camera.previewReaction(for: gesture)
                }
            }
        } header: {
            Text("Gesten und Zuordnungen · \(GestureKind.allCases.count)")
        } footer: {
            Text("Für jeden Slot stehen nur passende Reactions zur Auswahl. Unbelegte Gesten werden ebenfalls erkannt und hier angezeigt. Fingerherz und Herzhände sind experimentell: Halte beide Hände vollständig im Bild und möglichst frei von Verdeckungen.")
        }
    }

    private var status: String {
        guard camera.isRunning else { return "Kamera ist gestoppt" }
        guard camera.gestureConfiguration.enabled else { return "Gestenerkennung ist ausgeschaltet" }
        guard let gesture = camera.detectedGesture else { return "Zeige eine Handgeste" }
        let assigned = camera.gestureConfiguration.reaction(for: gesture)?.title ?? "Keine Reaction zugeordnet"
        return "\(gesture.title) · \(assigned)"
    }

    private func reaction(for gesture: GestureKind) -> Binding<ReactionKind?> {
        Binding(get: { camera.gestureConfiguration.reaction(for: gesture) },
                set: { camera.assignReaction($0, to: gesture) })
    }
}

private struct GestureSlotRow: View {
    let gesture: GestureKind
    @Binding var reaction: ReactionKind?
    let detected: Bool
    let canTest: Bool
    let test: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(gesture.emoji).font(.system(size: 30))
                    .frame(width: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(gesture.title).font(.headline)
                        if detected {
                            Text("Erkannt").font(.caption.weight(.medium)).foregroundStyle(.green)
                        }
                    }
                    Text(gesture.instruction).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Picker("Reaction", selection: $reaction) {
                    Text("Keine Reaction").tag(ReactionKind?.none)
                    ForEach(gesture.availableReactions) { available in
                        Text(available.title).tag(Optional(available))
                    }
                }
                .disabled(gesture.availableReactions.isEmpty)
                .accessibilityLabel("Reaction für \(gesture.title)")
                .accessibilityIdentifier("gesture-reaction-\(gesture.rawValue)")
                Button("Testen", systemImage: "play.fill", action: test)
                    .disabled(!canTest || reaction == nil)
                    .help("Reaction im Kamera-Ausgang abspielen")
                    .accessibilityLabel("\(gesture.title): Reaction testen")
            }
            if let reaction {
                Text(reaction.description).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(gesture.availableReactions.isEmpty
                     ? "Erkennbar · Noch keine passende Reaction verfügbar"
                     : "Erkennbar · Keine Reaction zugeordnet")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
