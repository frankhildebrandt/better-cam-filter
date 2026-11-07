<img src="assets/icon.svg" width="64" height="64" alt="">

# BetterCam

Native macOS-Webcam-App in SwiftUI mit Kameraauswahl, verarbeiteter Live-Vorschau
und einer CoreMediaIO Camera Extension als virtuelle Kamera **BetterCam**.
Optional ersetzt Vision den Hintergrund hinter einer Person durch ein eigenes Bild.
Die Kameraverarbeitung läuft lokal. Optional lassen sich neue Hintergrundbilder
über einen lokalen Codex App Server erzeugen.

## Voraussetzungen

- macOS 14+, Xcode mit Swift 6 und Command Line Tools.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) zum Neuerzeugen des mitgelieferten Xcode-Projekts (`brew install xcodegen`).
- Für die Installation der virtuellen Kamera: ein Apple Developer Team mit passenden
  Signierungsprofilen für App Groups und System Extensions. Ein unsignierter Build
  kann die Extension nicht aktivieren.

## Bauen und starten

```sh
xcodegen generate
open BetterCam.xcodeproj
```

In Xcode für **beide Targets** dasselbe Development Team wählen. Alternativ eine
nicht eingecheckte `Config/Local.xcconfig` anlegen:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Die Bundle IDs sind `de.bettercam.app` und `de.bettercam.camera`. Falls sie im
Developer Account nicht verfügbar sind, in `project.yml` ändern und die IDs in
`CameraConfiguration.swift`, `CameraDevice.authorizeProducer`, der App Group und
`CMIOExtensionMachServiceName` entsprechend angleichen. Die gemeinsame App Group
`$(TeamIdentifierPrefix)de.bettercam.camera` muss für beide Targets freigegeben sein.

1. Schema **BetterCam**, Ziel **My Mac**, bauen.
2. `BetterCam.app` aus dem Build-Verzeichnis nach **/Applications** kopieren.
3. App von dort öffnen und **Virtuelle Kamera aktivieren** klicken.
4. Die Kameraerweiterung in den Systemeinstellungen erlauben. Je nach macOS-Version
   unter **Allgemein → Anmeldeobjekte & Erweiterungen → Kameraerweiterungen** oder
   **Datenschutz & Sicherheit**. macOS kann einen Neustart verlangen.
5. Quelle auswählen, **Kamera starten**, Kamerazugriff erlauben.
6. In der Video-App **BetterCam** als Kamera wählen. Bereits geöffnete Video-Apps
   gegebenenfalls neu starten, damit sie das neue Gerät entdecken.

**Bild auswählen …** lädt einen Hintergrund und aktiviert den Filter. Der Schalter
stellt auf das unveränderte Kamerabild zurück. Kamera stoppen gibt die Hardware frei;
die installierte virtuelle Kamera bleibt verfügbar und liefert Schwarz. Zum Wechseln
der Quelle erst stoppen. Das Hintergrundbild wird nur für die laufende Sitzung gehalten.

## Hintergründe mit Codex erzeugen

Voraussetzung ist eine aktuelle Codex CLI mit angemeldetem Konto und verfügbarer
Bildgenerierung. Den App Server auf **demselben Mac** starten:

```sh
codex login
codex app-server --listen ws://127.0.0.1:4500
```

1. Unter **Hintergrund → Hintergrund erzeugen …** auf **Neu** klicken.
2. Einen Profilnamen und den **Pre-Prompt** mit den festen Vorgaben eintragen,
   beispielsweise Raumstil, Farben oder Markenregeln.
3. Optional über **Bilder hinzufügen …** Logos, Stilvorlagen und andere
   Referenzbilder importieren. BetterCam speichert eigene PNG-Kopien; die
   ursprünglichen Dateien müssen anschließend nicht mehr verfügbar sein.
4. **Profil speichern**, das Profil auswählen und bei Bedarf im Feld
   **Zusätzlicher Kontext** die Wünsche für dieses einzelne Bild ergänzen.
5. **Hintergrund erzeugen** klicken. Das fertige Bild wird als Kamerahintergrund
   aktiviert. Die Kamera muss zum Generieren nicht laufen.

Pre-Prompt und **alle** Profilbilder werden bei jeder Generierung erneut
übergeben. Der Zusatzkontext kann leer bleiben. Profile können über die
Stift-Schaltfläche bearbeitet oder über den Papierkorb gelöscht werden.
Profile, importierte Bilder und das zuletzt erzeugte Bild liegen im
Application-Support-Verzeichnis der App unter `BetterCam/Backgrounds`.
Das ausgewählte Profil und die Server-Adresse bleiben nach einem Neustart erhalten;
der aktive Kamerahintergrund wird weiterhin pro Sitzung gesetzt.

Unter **Codex App Server** lässt sich die lokale WebSocket-Adresse anpassen.
Die App akzeptiert ausschließlich Loopback-Adressen und behält ihre macOS-Sandbox;
die Kameraerweiterung erhält keinen Netzwerkzugriff. Es wird kein API-Key in
BetterCam gespeichert. Codex verwendet seine bestehende Anmeldung und Konfiguration.
Für jede Generierung wird ein eigener temporärer Thread mit `workspace-write` und
`approvalPolicy: never` angelegt. Interaktive Freigabeanfragen werden abgelehnt.
**Abbrechen** unterbricht den laufenden Turn. Bei Fehlern bleibt das bisherige
Kamerahintergrundbild aktiv.

Zur Bildgenerierung werden Pre-Prompt, Zusatzkontext und Profilbilder über Codex
an OpenAI übertragen. Die laufenden Kamerabilder werden dafür nicht verwendet.
Bildgenerierung muss vom verwendeten Codex-Konto unterstützt werden; BetterCam
zeigt Fehler des Servers an. Der WebSocket-Transport des App Servers ist
experimentell. Protokollgrundlage: [offizielle OpenAI-Dokumentation zum Codex App Server](https://learn.chatgpt.com/docs/app-server).

## Architektur

```text
AVCaptureDevice → AVCaptureVideoDataOutput
  → FrameProcessor (Core Image, optional Vision-Personenmaske)
  ├─ verarbeitete SwiftUI-Vorschau (bis zu 15 FPS)
  └─ CoreMediaIO Sink-Queue → Camera Extension → Source-Stream
                                              → Video-Apps / Browser
```

- **App/Camera:** Capture und Verarbeitung auf einer seriellen Queue, veraltete
  Eingangsframes werden verworfen. Ausgabe in 1280 × 720 BGRA, bis zu 30 FPS,
  mit IOSurface-Puffern und begrenztem Pool. Die Extension wird bei Bedarf alle
  zwei Sekunden erneut gesucht, sodass die Vorschau auch ohne Installation läuft.
- **CameraExtension:** stabiles Geräte-/Stream-UUID-Paar und Source-/Sink-Streams.
  Ein Producer gleichzeitig, auf die App-Signatur-ID beschränkt. Die Extension
  konsumiert auch ohne Zuschauer und sendet an alle Kamera-Clients. Ohne aktuelle
  Frames spätestens nach 500 ms Schwarz; beim regulären Stop wird das letzte Bild
  sofort verworfen. Die Kamera gibt keine eigenen Hardware-Captures in Auftrag.
- **Shared:** Ausgabeformat, Seitenverhältnis, Masken-Compositing und Sample-Puffer.
  Weitere Filter werden vor dem Rendern in `FrameProcessor` ergänzt und gelten
  damit gleichzeitig für Vorschau und virtuelle Kamera.

720p/30 ist das Ausgabeformat, keine garantierte Verarbeitungsleistung. Vision und
Kamerahardware bestimmen die effektive Bildrate; die Extension wiederholt bei kurzen
Lücken den letzten Frame. Die Personenmaske ist für Menschen gedacht und kann an
Haaren, schnellen Bewegungen oder bei schlechtem Licht sichtbare Kanten erzeugen.
Audio, Aufnahme und Distribution/Notarisierung sind nicht Teil dieses Bootstraps.

## Prüfen

```sh
# Kompiliert App und eingebettete Extension ohne Apple-Signierung:
xcodebuild -project BetterCam.xcodeproj -scheme BetterCam \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

# Tests für Bildverarbeitung, Profil-/Asset-Speicherung und den Codex-JSON-RPC-Ablauf:
swift test
```

Ein erfolgreicher Build und diese Tests ersetzen keinen Installationstest. Für den
End-to-End-Test auf einem Mac: signieren und installieren, BetterCam beispielsweise
in QuickTime auswählen, Quelle und Bildfilter prüfen, Stop/Start, USB-Abziehen und
App-Beenden testen. Nach spätestens 500 ms ohne Producer muss Schwarz erscheinen;
die eigene virtuelle Kamera darf nicht als Eingangsquelle angeboten werden.

Das Xcode-Projekt und generierte Plists/Entitlements werden mitgeliefert; `project.yml`
ist die Quelle für Änderungen an Targets, Build-Einstellungen und Capabilities.

Technische Grundlage: [Apples Camera-Extension-Anleitung](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
und [WWDC22: Create camera extensions with Core Media IO](https://developer.apple.com/videos/play/wwdc2022/10022/).
