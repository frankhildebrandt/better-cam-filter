import SwiftUI

struct PreviewView: View {
    let image: CGImage?
    let isRunning: Bool

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.065, blue: 0.08)
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    .accessibilityLabel("Verarbeitete Kamera-Vorschau")
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isRunning ? "camera.aperture" : "video.slash")
                        .font(.system(size: 38, weight: .light))
                    Text(isRunning ? "Warte auf Kamerabild …" : "Dein Bild beginnt hier")
                        .font(.headline)
                    Text(isRunning ? "Die Kamera wird vorbereitet." : "Wähle eine Kamera und starte die Vorschau.")
                        .font(.callout).foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
