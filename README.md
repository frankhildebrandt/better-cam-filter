<img src="App/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="64" height="64" alt="BetterCam App-Icon">

# BetterCam

Native macOS-Webcam-App in SwiftUI mit Kameraauswahl, verarbeiteter Live-Vorschau
und einer CoreMediaIO Camera Extension als virtuelle Kamera **BetterCam**.
Optional ersetzt Vision den Hintergrund hinter Personen und erkannten Vordergrundobjekten
durch ein eigenes Bild. Die Ausgabe erfolgt in Full HD (1920 × 1080).
Die Kameraverarbeitung läuft lokal. Optional lassen sich neue Hintergrundbilder
über einen lokalen Codex App Server erzeugen.

Das App-Icon liegt in `App/Assets.xcassets/AppIcon.appiconset` mit allen macOS-Größen
von 16 bis 1024 Pixeln. Xcode erzeugt daraus das Dock-/Finder-Icon; der App-Kopf nutzt
dasselbe Icon. Der Entwurf wurde mit dem integrierten Imagegen-Werkzeug erstellt;
der vollständige Prompt steht in [`assets/bettercam-icon-prompt.txt`](assets/bettercam-icon-prompt.txt).

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

Um ein vorhandenes **Developer ID Application**-Zertifikat für beide Targets zu
verwenden, zusätzlich in derselben Datei eintragen:

```xcconfig
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Developer ID Application
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO
BETTERCAM_APP_PROFILE = BetterCam Developer ID
BETTERCAM_CAMERA_PROFILE = BetterCam Camera Developer ID
```

Die lokale Konfiguration gilt für Debug und Release und bleibt beim Neuerzeugen
des Projekts erhalten. Die beiden Profilnamen müssen zu den lokal installierten
Developer-ID-Profilen passen. Für die App ist **System Extension** erforderlich; die Profile
müssen zu Team, Bundle IDs, Zertifikat und aktivierten Capabilities passen.
Das Zertifikat allein ersetzt diese Berechtigungen nicht. Mit
`xcodebuild -allowProvisioningUpdates` kann Xcode bei manueller Signierung bereits
vorhandene Profile aus dem angemeldeten Konto laden.
Developer-ID-Builds enthalten keine Debugger-Berechtigung (`get-task-allow`). Für
eine Debugger-Sitzung stattdessen ein Development-Zertifikat und Development-Profile
verwenden und die lokale Einstellung `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` entfernen.

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

## Vordergrund und Schutzbereiche

**Erkennung → Person + Zubehör** ist der Standard. Die genaue Vision-Personenmaske
bildet die Basis; daran wird Zubehör gezielt ergänzt. Allgemeine Vision-Instanzen
werden nicht mehr pauschal übernommen, damit Tür oder Whiteboard bei wechselnder
Erkennung nicht als neue Vordergrundobjekte erscheinen. **Nur Person** verwendet
dieselbe Personenmaske ohne die automatische Zubehör-Ergänzung.

**Stuhl & Mikrofon ergänzen** ist im Objektmodus standardmäßig aktiv. Ein lokaler
Algorithmus sucht zusammenhängende dunkle, wenig gesättigte Flächen nahe der bereits
erkannten Person. Schmale farbige Komponenten ergänzen beispielsweise ein Kabel;
kurze Verbindungsstücke überbrücken helle Metallteile. Neue unabhängige Zubehörbereiche
benötigen mindestens drei aufeinanderfolgende Beobachtungen über mindestens 100 ms.
Bestätigtes Zubehör bleibt bei positiver Erkennung auch bei Farbsprüngen erhalten;
seine Farbreferenz folgt laufenden Belichtungsänderungen. Ausblenden benötigt mindestens
drei negative Beobachtungen über 200 ms. Bei deutlich anderem freigelegtem Hintergrund
reichen zwei negative Beobachtungen über mindestens 60 ms. Eine Wiedererkennung vor
der Freigabe gilt sofort. Die Personenmaske selbst wird weder verzögert noch mit alten
Kopfkonturen überblendet.

Seit Version 0.4.2 übernehmen bewegte Komponenten die bestehende Bestätigung in einem
begrenzten Randbereich (2 % der Analysebreite), wenn mindestens 40 % der aktuellen
Komponente mit farblich passenden bestätigten Pixeln überlappen. Unabhängige neue
Bereiche durchlaufen weiterhin die anfängliche Mehrbildprüfung. Szenenwechsel werden
an Hintergrundpixeln außerhalb der aktuellen und vorherigen Personenmaske sowie des
Zubehörs gemessen, damit Personenbewegungen nicht die gesamte Zubehörhistorie löschen.

Seit Version 0.4.1 bleibt die Zubehör-Bestätigung auch dann bestehen, wenn Vision
dasselbe Objekt zwischenzeitlich zur vollständig opaken Personenmaske zählt.
Die akzeptierten Objektkomponenten liefern dafür eigene Evidenz unabhängig vom
Personenalpha. Fällt etwa das Mikrofon später wieder aus der Personenmaske heraus,
ist seine Zubehörmaske bereits bestätigt. Personenalpha allein erzeugt dabei keine
Zubehörhistorie; bestätigte Gegenbelege, fehlender Personenanker und die Reset-Regeln bleiben wirksam.

Komponenten benötigen mehrere Stützpixel im Bereich des Oberkörpers. Kleine dunkle
Flecken und Striche werden nicht als eigenständiges Zubehör ergänzt. Bei zu großen
Erweiterungen werden einzelne Kandidaten abgelehnt, statt die gesamte Zubehörmaske
gleichzeitig aus- und wieder einzuschalten. Die Historie wird bei Stop/Start,
Modus-/Hintergrundwechsel, Zubehör-Umschaltung, neuer Quellgröße, Szenenwechsel,
Segmentierungsfehlern und längeren Frame-Pausen zurückgesetzt. Es werden keine
Koordinaten oder Farben aus dem Testfoto als feste Maske übernommen.

Die Ergänzung ist eine Erscheinungsheuristik, keine semantische Stuhl- oder
Mikrofonerkennung. Große zusätzliche Flächen und Verbindungen zum oberen Bildrand
werden verworfen; dennoch können kleine nahe dunkle Raumobjekte mit aufgenommen
werden. Bei dunklem Hintergrund den Schalter ausschalten oder auf **Nur Person**
mit gezielten Schutzmarkierungen wechseln.

Falls ein Gegenstand verschwindet: **Bereiche behalten** einschalten und im
Originalbild mit dem Pinsel darübermalen. **Pinselgröße**, **Rückgängig** und
**Löschen** korrigieren die Markierung. Anschließend den Bearbeitungsmodus ausschalten;
die Markierungen bleiben aktiv. Die virtuelle Kamera erhält auch während des Markierens
weiter das gefilterte Bild. Schutzbereiche sind feste Bildbereiche und folgen keinen
Objekten: Darin bleibt das gesamte Original sichtbar, einschließlich Raumhintergrund.
Nach einem Kameraschwenk die Markierungen korrigieren; ein Wechsel der Kamera löscht sie.

Die Statuszeile zeigt die tatsächliche Eingangsauflösung und die gemessene
Verarbeitungsbildrate. Wenn die Kamera Full HD nicht unterstützt, wird eine verfügbare
Auflösung verwendet und für die Ausgabe auf Full HD skaliert.

Nach dem Update von 720p auf Full HD die App neu starten und eine bereits installierte
Kameraerweiterung erneut aktivieren, damit auch sie das neue Full-HD-Format bereitstellt.

## Architektur

```text
AVCaptureDevice → AVCaptureVideoDataOutput
  → FrameProcessor (Core Image, Vision-Vordergrundmaske + Schutzbereiche)
  ├─ verarbeitete SwiftUI-Vorschau (bis zu 15 FPS)
  └─ CoreMediaIO Sink-Queue → Camera Extension → Source-Stream
                                              → Video-Apps / Browser
```

- **App/Camera:** Capture und Verarbeitung auf einer seriellen Queue, veraltete
  Eingangsframes werden verworfen. Ausgabe in 1920 × 1080 BGRA, bis zu 30 FPS,
  mit IOSurface-Puffern und begrenztem Pool. Die Extension wird bei Bedarf alle
  zwei Sekunden erneut gesucht, sodass die Vorschau auch ohne Installation läuft.
- **CameraExtension:** stabiles Geräte-/Stream-UUID-Paar und Source-/Sink-Streams.
  Ein Producer gleichzeitig, auf die App-Signatur-ID beschränkt. Die Extension
  konsumiert auch ohne Zuschauer und sendet an alle Kamera-Clients. Ohne aktuelle
  Frames spätestens nach 500 ms Schwarz; beim regulären Stop wird das letzte Bild
  sofort verworfen. Die Kamera gibt keine eigenen Hardware-Captures in Auftrag.
- **Shared:** Ausgabeformat, Seitenverhältnis, Vision-Segmentierung, Schutzmaske,
  Masken-Compositing und Sample-Puffer. Masken werden in normalisierten Koordinaten
  auf das bereits zugeschnittene Kamerabild abgebildet, ohne erneuten Aspect-Fill-Crop.
  `AccessoryMaskRefiner` analysiert Bild und Maske bei 512 Pixeln Breite.
  `AccessoryRegions` ergänzt begrenzt verbundene Komponenten. `AccessoryTemporalFilter`
  bestätigt nur zusätzliche Zubehörpixel; die aktuelle hochauflösende Personenmaske
  und explizite Schutzbereiche bleiben davon unabhängig.
  Weitere Filter werden vor dem Rendern in `FrameProcessor` ergänzt und gelten
  damit gleichzeitig für Vorschau und virtuelle Kamera.

1080p/30 ist das Ausgabeformat, keine garantierte Verarbeitungsleistung. Vision und
Kamerahardware bestimmen die effektive Bildrate; die Extension wiederholt bei kurzen
Lücken den letzten Frame. Die Vision-Analyse arbeitet auf einem verkleinerten Bild
mit maximal 768 Pixeln Breite; die Komposition rendert in Full HD. Segmentierung kann
an Haaren, schnellen Bewegungen oder bei schlechtem Licht sichtbare Kanten erzeugen.
Audio, Aufnahme und Distribution/Notarisierung sind nicht Teil dieses Bootstraps.

## Prüfen

```sh
# Kompiliert App und eingebettete Extension ohne Apple-Signierung:
xcodebuild -project BetterCam.xcodeproj -scheme BetterCam \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

# Tests für Bildverarbeitung, Schutzpinsel, Full HD, Profile, Assets und Codex-JSON-RPC:
swift test

# Vergleich aus einem lokalen Kamerabild (optional: Screenshot-Crop in Pixeln ab links oben):
swiftc -O -swift-version 6 Shared/*.swift Tools/InspectMask.swift -o /tmp/inspect-mask
/tmp/inspect-mask /path/to/camera.png build/mask-evaluation
# /tmp/inspect-mask /path/to/window.png build/mask-evaluation 336 136 681 383
```

Das Diagnosewerkzeug erzeugt `before.png`, `after.png` und `mask.png` lokal und
schaltet keine Kamera ein. Eigene Kamerabilder gehören nicht ins Git-Repository;
der Ausgabeordner `build/` ist ignoriert. Die Tests decken unter anderem Stuhl,
Arm, farbiges Kabel, kurze Verbinder, unveränderte weiche Personenränder und
abgelehnte dunkle Hintergrundflächen ab. Zeitliche Regressionstests prüfen positive
Erkennung bei Farbdrift, kurze Erkennungslücken, bestätigte Entfernung, bewegte
Mikrofonkanten und den Wechsel zwischen Personen- und Zubehörmaske.

Ein erfolgreicher Build und diese Tests ersetzen keinen Installationstest. Für den
End-to-End-Test auf einem Mac: signieren und installieren, BetterCam beispielsweise
in QuickTime auswählen, Quelle und Bildfilter prüfen, Stop/Start, USB-Abziehen und
App-Beenden testen. Kopfkontur, Mikrofon, Stuhl und Schutzbereiche bei Bewegung prüfen.
Beim Markieren muss der virtuelle Ausgang weiter gefiltert bleiben. Nach spätestens
500 ms ohne Producer muss Schwarz erscheinen;
die eigene virtuelle Kamera darf nicht als Eingangsquelle angeboten werden.

Das Xcode-Projekt und generierte Plists/Entitlements werden mitgeliefert; `project.yml`
ist die Quelle für Änderungen an Targets, Build-Einstellungen und Capabilities.

## Recherche zu Segmentierung und Matting (7. November 2026)

- [Apples Foreground Instance Masks](https://developer.apple.com/videos/play/wwdc2023/10176/):
  native Segmentierung allgemeiner Vordergrundobjekte ab macOS 14. Diese Version
  wurde zunächst als Basis verwendet. Seit Version 0.4 verwendet die App stattdessen
  die Personenmaske als festen semantischen Anker, weil wechselnde allgemeine Instanzen
  Raumobjekte freigeben konnten. Keine zusätzlichen Gewichte und keine Server erforderlich.
- [Robust Video Matting (RVM)](https://github.com/PeterL1n/RobustVideoMatting):
  zeitliches Gedächtnis und Core-ML-Unterstützung sind für flackerarme Personenmasken
  interessant. Es ist ausdrücklich für Human Matting trainiert; ein Erhalt von
  Mikrofon und Stuhl folgt daraus nicht. Der offizielle Code steht unter GPL-3.0.
- [SAM 3 / SAM 3.1](https://github.com/facebookresearch/sam3):
  segmentiert und verfolgt Objekte mit Text- und Bildprompts. Damit ist es ein Kandidat
  für explizit ausgewählte Personen, Mikrofone und Stühle. Metas Referenzimplementierung
  setzt Python/PyTorch und CUDA voraus; Kantengüte und Kameraleistung müssen vor einer
  Integration gemessen werden.
- [SAM 3 mit Apples Core AI](https://developer.apple.com/videos/play/wwdc2026/326/):
  Apple bietet inzwischen auch eine native Swift-Integration für textgesteuerte
  SAM-3-Bildsegmentierung. Sie benötigt macOS 27; auf diesem Mac läuft aktuell
  macOS 26.6.2. Damit ist sie ein sinnvoller späterer Integrationskandidat, aber kein
  direkt nutzbarer Ersatz in diesem Build. Ein vollständiger Video-Tracker und
  garantierte 1080p/30 werden durch die Bildsegmentierungs-API nicht zugesagt.
- [SAM 2](https://ai.meta.com/research/sam2/):
  Objektauswahl per Klick und zeitliche Verfolgung passen zum Anwendungsfall.
  Der [Hugging-Face-Core-ML-Port](https://github.com/huggingface/segment-anything-2)
  unterstützt laut README bislang nur Bildsegmentierung, keinen vollständigen
  Video-Tracker. Ein Image-Encoder allein ersetzt keine zeitliche Video-Pipeline.
- [Background Matting V2](https://github.com/PeterL1n/BackgroundMattingV2):
  nutzt zusätzlich ein aufgenommenes Referenzbild des leeren Hintergrunds. Als
  alternative Kalibrierung für eine feste Kamera interessant; Eignung für beliebige
  Gegenstände und Laufzeit auf Apple Silicon sind damit noch nicht belegt.

Empfehlung: Für die aktuelle native App Vision plus Schutzbereiche verwenden.
Für eine spätere automatische Verfolgung explizit gewählter Gegenstände SAM evaluieren;
für bessere Personenränder RVM separat bewerten. Die publizierten NVIDIA-FPS sind
keine Leistungszusage für diesen Mac. Keines dieser externen Modelle ist eingebaut.

Technische Grundlage: [Apples Camera-Extension-Anleitung](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
und [WWDC22: Create camera extensions with Core Media IO](https://developer.apple.com/videos/play/wwdc2022/10022/).
